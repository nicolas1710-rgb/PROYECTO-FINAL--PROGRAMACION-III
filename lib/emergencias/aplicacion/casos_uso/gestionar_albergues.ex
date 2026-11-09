defmodule Emergencias.Aplicacion.CasosUso.GestionarAlbergues do
  @moduledoc """
  Caso de uso para el registro de albergues, control estricto de cupo y entradas/salidas.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoAlbergues

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Albergue, Usuario}
  alias Emergencias.Dominio.Reglas.{Ocupacion, Permisos, Validaciones}
  alias Emergencias.Infraestructura.Procesos.Albergue, as: ProcesoAlbergue

  @registro Emergencias.RegistroAlbergues

  @impl true
  @doc """
  Registrar un nuevo albergue en el sistema con su capacidad máxima.
  """
  @spec registrar_albergue(map(), Usuario.t(), keyword()) :: {:ok, Albergue.t()} | {:error, atom()}
  def registrar_albergue(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_albergue),
         {:ok, datos} <- Validaciones.validar_entrada_albergue(params) do
      repositorio = obtener_repositorio(opciones)
      bitacora = obtener_bitacora(opciones)
      reloj = obtener_reloj(opciones)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_albergues(repositorio)
      nuevo_id = GeneradorId.formatear_id(:albergue, length(existentes) + 1)

      {:ok, nuevo_alb} =
        Albergue.construir(%{
          id: nuevo_id,
          nombre: datos.nombre,
          codigo_zona: datos.codigo_zona,
          capacidad_maxima: datos.capacidad_maxima,
          fecha_registro: fecha,
          personas_alojadas: MapSet.new()
        })

      guardar_albergue(repositorio, nuevo_alb)
      notificar_bitacora(bitacora, usuario.nombre, "registrar_albergue", "Albergue #{nuevo_id} registrado", fecha)

      repo_personalizado = Keyword.get(opciones, :repositorio)
      if is_nil(repo_personalizado) do
        iniciar_proceso_albergue(nuevo_alb, opciones)
      end

      {:ok, nuevo_alb}
    end
  end

  @impl true
  @doc """
  Consultar el estado de ocupación y datos de un albergue.
  """
  @spec consultar_albergue(String.t(), Usuario.t(), keyword()) :: {:ok, Albergue.t()} | {:error, atom()}
  def consultar_albergue(id_albergue, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :consultar_albergue) do
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if proceso_activo?(id_albergue) and is_nil(repo_personalizado) do
        ProcesoAlbergue.consultar(id_albergue)
      else
        repositorio = obtener_repositorio(opciones)

        case buscar_albergue(repositorio, id_albergue) do
          {:ok, %Albergue{} = alb} -> {:ok, alb}
          _ -> {:error, :albergue_no_encontrado}
        end
      end
    end
  end

  @impl true
  @doc """
  Registrar el ingreso de una persona a un albergue.
  """
  @spec registrar_entrada(String.t(), String.t(), Usuario.t(), keyword()) ::
          {:ok, Albergue.t()} | {:error, atom()}
  def registrar_entrada(id_albergue, documento, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_entrada_albergue),
         {:ok, doc_valido} <- Validaciones.validar_documento(documento) do
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if proceso_activo?(id_albergue) and is_nil(repo_personalizado) do
        ProcesoAlbergue.ingresar_persona(id_albergue, doc_valido)
      else
        ejecutar_entrada_directa(id_albergue, doc_valido, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Registrar la salida de una persona de un albergue.
  """
  @spec registrar_salida(String.t(), String.t(), Usuario.t(), keyword()) ::
          {:ok, Albergue.t()} | {:error, atom()}
  def registrar_salida(id_albergue, documento, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_salida_albergue),
         {:ok, doc_valido} <- Validaciones.validar_documento(documento) do
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if proceso_activo?(id_albergue) and is_nil(repo_personalizado) do
        ProcesoAlbergue.retirar_persona(id_albergue, doc_valido)
      else
        ejecutar_salida_directa(id_albergue, doc_valido, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Listar todos los albergues registrados.
  """
  @spec listar_albergues(Usuario.t(), keyword()) :: {:ok, list(Albergue.t())} | {:error, atom()}
  def listar_albergues(%Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :consultar_albergue) do
      repositorio = obtener_repositorio(opciones)
      cargar_albergues(repositorio)
    end
  end

  defp proceso_activo?(codigo) do
    if Process.whereis(@registro) != nil do
      case Registry.lookup(@registro, codigo) do
        [{_pid, _}] -> true
        [] -> false
      end
    else
      false
    end
  end

  defp ejecutar_entrada_directa(id_albergue, doc, usuario, opciones) do
    repositorio = obtener_repositorio(opciones)
    bitacora = obtener_bitacora(opciones)
    reloj = obtener_reloj(opciones)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, %Albergue{} = alb} <- buscar_albergue(repositorio, id_albergue),
         {:ok, alb_actualizado} <- Ocupacion.ingresar_persona(alb, doc) do
      guardar_albergue(repositorio, alb_actualizado)
      notificar_bitacora(bitacora, usuario.nombre, "entrada_albergue", "Ingreso #{doc} a #{id_albergue}", fecha)
      {:ok, alb_actualizado}
    end
  end

  defp ejecutar_salida_directa(id_albergue, doc, usuario, opciones) do
    repositorio = obtener_repositorio(opciones)
    bitacora = obtener_bitacora(opciones)
    reloj = obtener_reloj(opciones)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, %Albergue{} = alb} <- buscar_albergue(repositorio, id_albergue),
         {:ok, alb_actualizado} <- Ocupacion.retirar_persona(alb, doc) do
      guardar_albergue(repositorio, alb_actualizado)
      notificar_bitacora(bitacora, usuario.nombre, "salida_albergue", "Salida #{doc} de #{id_albergue}", fecha)
      {:ok, alb_actualizado}
    end
  end

  defp iniciar_proceso_albergue(%Albergue{} = alb, _opciones) do
    sup = Emergencias.Infraestructura.Procesos.SupervisorAlbergues
    if Process.whereis(sup) != nil do
      Emergencias.Infraestructura.Procesos.SupervisorAlbergues.iniciar_albergue(alb)
    else
      :ok
    end
  end

  defp buscar_albergue(repo, id) do
    {:ok, lista} = cargar_albergues(repo)
    encontrado = Enum.find(lista, fn a -> String.upcase(a.id) == String.upcase(id) end)
    if encontrado, do: {:ok, encontrado}, else: {:error, :albergue_no_encontrado}
  end

  defp obtener_repositorio(opts),
    do: Keyword.get(opts, :repositorio, Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo)

  defp obtener_bitacora(opts),
    do: Keyword.get(opts, :bitacora, Emergencias.Infraestructura.Procesos.BitacoraActividad)

  defp obtener_reloj(opts), do: Keyword.get(opts, :reloj, Reloj)

  defp cargar_albergues(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:albergues), else: {:ok, []}
  end

  defp guardar_albergue(repo, alb) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:albergues, alb), else: :ok
  end

  defp notificar_bitacora(bitacora, u, a, d, f) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(u, a, d, f)
    else
      :ok
    end
  end
end
