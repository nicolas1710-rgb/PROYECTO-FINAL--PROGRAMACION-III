defmodule Emergencias.Aplicacion.CasosUso.GestionarAlbergues do
  @moduledoc """
  Caso de uso para el registro de albergues, control estricto de cupo y entradas/salidas.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoAlbergues

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Albergue, Usuario}
  alias Emergencias.Dominio.Reglas.{Ocupacion, Permisos, Validaciones}

  @impl true
  @doc """
  Registrar un nuevo albergue en el sistema con su capacidad máxima.
  """
  @spec registrar_albergue(map(), Usuario.t(), keyword()) :: {:ok, Albergue.t()} | {:error, atom()}
  def registrar_albergue(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_albergue),
         {:ok, _datos} <- Validaciones.validar_entrada_albergue(params) do
      puerto_alb = resolver_puerto(opciones, :puerto_albergues, :puerto_albergues)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        exportar_funcion?(puerto_alb, :registrar, 2) ->
          case puerto_alb.registrar(params, usuario.nombre) do
            {:ok, alb} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_albergue", "Albergue #{alb.id} registrado", fecha)
              {:ok, alb}

            error ->
              error
          end

        true ->
          ejecutar_registro_directo(params, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Consultar el estado de ocupación y datos de un albergue.
  """
  @spec consultar_albergue(String.t(), Usuario.t(), keyword()) :: {:ok, Albergue.t()} | {:error, atom()}
  def consultar_albergue(id_albergue, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :consultar_albergue) do
      puerto_alb = resolver_puerto(opciones, :puerto_albergues, :puerto_albergues)

      cond do
        exportar_funcion?(puerto_alb, :consultar, 1) ->
          puerto_alb.consultar(id_albergue)

        true ->
          repositorio = Keyword.get(opciones, :repositorio)

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
      puerto_alb = resolver_puerto(opciones, :puerto_albergues, :puerto_albergues)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        exportar_funcion?(puerto_alb, :ingresar, 2) ->
          case puerto_alb.ingresar(id_albergue, doc_valido) do
            {:ok, alb} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "entrada_albergue", "Ingreso #{doc_valido} a #{id_albergue}", fecha)
              {:ok, alb}

            error ->
              error
          end

        true ->
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
      puerto_alb = resolver_puerto(opciones, :puerto_albergues, :puerto_albergues)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        exportar_funcion?(puerto_alb, :salir, 2) ->
          case puerto_alb.salir(id_albergue, doc_valido) do
            {:ok, alb} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "salida_albergue", "Salida #{doc_valido} de #{id_albergue}", fecha)
              {:ok, alb}

            error ->
              error
          end

        true ->
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
      puerto_alb = resolver_puerto(opciones, :puerto_albergues, :puerto_albergues)

      cond do
        exportar_funcion?(puerto_alb, :listar, 0) ->
          puerto_alb.listar()

        true ->
          repositorio = Keyword.get(opciones, :repositorio)
          cargar_albergues(repositorio)
      end
    end
  end

  @doc """
  Asociar suministros o recursos a un albergue.
  """
  @spec asociar_recurso(String.t(), String.t(), pos_integer(), Usuario.t(), keyword()) ::
          {:ok, Albergue.t()} | {:error, atom()}
  def asociar_recurso(id_albergue, id_recurso, cantidad, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_albergue) do
      puerto_alb = resolver_puerto(opciones, :puerto_albergues, :puerto_albergues)

      if exportar_funcion?(puerto_alb, :asociar_recurso, 3) do
        puerto_alb.asociar_recurso(id_albergue, id_recurso, cantidad)
      else
        {:error, :no_implementado}
      end
    end
  end

  @doc """
  Asociar una necesidad humanitaria al albergue.
  """
  @spec asociar_necesidad(String.t(), String.t(), Usuario.t(), keyword()) ::
          {:ok, Albergue.t()} | {:error, atom()}
  def asociar_necesidad(id_albergue, id_necesidad, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_albergue) do
      puerto_alb = resolver_puerto(opciones, :puerto_albergues, :puerto_albergues)

      if exportar_funcion?(puerto_alb, :asociar_necesidad, 2) do
        puerto_alb.asociar_necesidad(id_albergue, id_necesidad)
      else
        {:error, :no_implementado}
      end
    end
  end

  defp resolver_puerto(opciones, clave, config_key) do
    cond do
      Keyword.has_key?(opciones, clave) -> Keyword.get(opciones, clave)
      Keyword.has_key?(opciones, :repositorio) -> nil
      true -> Application.get_env(:emergencias, config_key)
    end
  end

  defp exportar_funcion?(modulo, funcion, aridad) do
    is_atom(modulo) and modulo != nil and Code.ensure_loaded?(modulo) and function_exported?(modulo, funcion, aridad)
  end

  defp ejecutar_registro_directo(params, usuario, opciones) do
    with {:ok, datos} <- Validaciones.validar_entrada_albergue(params) do
      repositorio = Keyword.get(opciones, :repositorio)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_albergues(repositorio)
      nuevo_id = Map.get(params, :id) || GeneradorId.formatear_id(:albergue, length(existentes) + 1)

      {:ok, nuevo_alb} =
        Albergue.construir(%{
          id: nuevo_id,
          nombre: datos.nombre,
          codigo_zona: datos.codigo_zona,
          capacidad_maxima: datos.capacidad_maxima,
          fecha_registro: fecha,
          personas_alojadas: MapSet.new(),
          recursos_asignados: %{},
          necesidades_asociadas: []
        })

      guardar_albergue(repositorio, nuevo_alb)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_albergue", "Albergue #{nuevo_id} registrado", fecha)
      {:ok, nuevo_alb}
    end
  end

  defp ejecutar_entrada_directa(id_albergue, doc, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, %Albergue{} = alb} <- buscar_albergue(repositorio, id_albergue),
         {:ok, alb_actualizado} <- Ocupacion.ingresar_persona(alb, doc) do
      guardar_albergue(repositorio, alb_actualizado)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "entrada_albergue", "Ingreso #{doc} a #{id_albergue}", fecha)
      {:ok, alb_actualizado}
    end
  end

  defp ejecutar_salida_directa(id_albergue, doc, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, %Albergue{} = alb} <- buscar_albergue(repositorio, id_albergue),
         {:ok, alb_actualizado} <- Ocupacion.retirar_persona(alb, doc) do
      guardar_albergue(repositorio, alb_actualizado)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "salida_albergue", "Salida #{doc} de #{id_albergue}", fecha)
      {:ok, alb_actualizado}
    end
  end

  defp buscar_albergue(nil, _id), do: {:error, :albergue_no_encontrado}
  defp buscar_albergue(repo, id) do
    {:ok, lista} = cargar_albergues(repo)
    encontrado = Enum.find(lista, fn a -> String.upcase(a.id) == String.upcase(id) end)
    if encontrado, do: {:ok, encontrado}, else: {:error, :albergue_no_encontrado}
  end

  defp cargar_albergues(nil), do: {:ok, []}
  defp cargar_albergues(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:albergues), else: {:ok, []}
  end

  defp guardar_albergue(nil, _alb), do: :ok
  defp guardar_albergue(repo, alb) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:albergues, alb), else: :ok
  end

  defp notificar_bitacora(nil, _u, _a, _d, _f), do: :ok
  defp notificar_bitacora(bitacora, u, a, d, f) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(u, a, d, f)
    else
      :ok
    end
  end
end
