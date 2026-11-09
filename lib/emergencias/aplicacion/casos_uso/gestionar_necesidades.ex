defmodule Emergencias.Aplicacion.CasosUso.GestionarNecesidades do
  @moduledoc """
  Caso de uso para registrar, consultar y actualizar el estado de necesidades humanitarias.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoNecesidades

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Necesidad, Usuario}
  alias Emergencias.Dominio.Reglas.{Permisos, TransicionesEstado, Validaciones}
  alias Emergencias.Infraestructura.Procesos.GestorNecesidades

  @impl true
  @doc """
  Registrar una nueva necesidad reportada para una zona.
  """
  @spec registrar_necesidad(map(), Usuario.t(), keyword()) :: {:ok, Necesidad.t()} | {:error, atom()}
  def registrar_necesidad(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_necesidad) do
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if Process.whereis(GestorNecesidades) != nil and is_nil(repo_personalizado) do
        GestorNecesidades.registrar_necesidad(params, usuario.nombre)
      else
        ejecutar_registro_directo(params, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Listar necesidades aplicando filtros opcionales de zona, prioridad o estado.
  """
  @spec listar_necesidades(keyword(), Usuario.t(), keyword()) ::
          {:ok, list(Necesidad.t())} | {:error, atom()}
  def listar_necesidades(filtros, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :listar_necesidades) do
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if Process.whereis(GestorNecesidades) != nil and is_nil(repo_personalizado) do
        GestorNecesidades.listar_necesidades(filtros)
      else
        repositorio = obtener_repositorio(opciones)
        {:ok, lista} = cargar_necesidades(repositorio)
        {:ok, aplicar_filtros(lista, filtros)}
      end
    end
  end

  @impl true
  @doc """
  Actualizar el estado de una necesidad previa validación de grafo de transiciones.
  """
  @spec actualizar_necesidad(String.t(), atom(), Usuario.t(), keyword()) ::
          {:ok, Necesidad.t()} | {:error, atom()}
  def actualizar_necesidad(id_necesidad, nuevo_estado, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :actualizar_necesidad) do
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if Process.whereis(GestorNecesidades) != nil and is_nil(repo_personalizado) do
        GestorNecesidades.actualizar_estado(id_necesidad, nuevo_estado, usuario.nombre)
      else
        ejecutar_actualizacion_directa(id_necesidad, nuevo_estado, usuario, opciones)
      end
    end
  end

  defp ejecutar_registro_directo(params, usuario, opciones) do
    with {:ok, datos_validados} <- Validaciones.validar_entrada_necesidad(params) do
      repositorio = obtener_repositorio(opciones)
      bitacora = obtener_bitacora(opciones)
      reloj = obtener_reloj(opciones)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_necesidades(repositorio)
      nuevo_id = GeneradorId.formatear_id(:necesidad, length(existentes) + 1)

      {:ok, nueva_nec} =
        Necesidad.construir(%{
          id: nuevo_id,
          codigo_zona: datos_validados.codigo_zona,
          tipo_recurso: datos_validados.tipo_recurso,
          cantidad_solicitada: datos_validados.cantidad_solicitada,
          prioridad: datos_validados.prioridad,
          estado: :pendiente,
          fecha_registro: fecha,
          usuario_reporta: usuario.nombre
        })

      guardar_necesidad(repositorio, nueva_nec)
      notificar_bitacora(bitacora, usuario.nombre, "registrar_necesidad", "Necesidad #{nuevo_id} reportada", fecha)
      {:ok, nueva_nec}
    end
  end

  defp ejecutar_actualizacion_directa(id_necesidad, nuevo_estado, usuario, opciones) do
    repositorio = obtener_repositorio(opciones)
    bitacora = obtener_bitacora(opciones)
    reloj = obtener_reloj(opciones)
    fecha = reloj.obtener_fecha_actual()

    case buscar_necesidad(repositorio, id_necesidad) do
      {:ok, %Necesidad{} = actual} ->
        with {:ok, transitada} <- TransicionesEstado.transitar_necesidad(actual, nuevo_estado, usuario.nombre, fecha) do
          guardar_necesidad(repositorio, transitada)
          notificar_bitacora(bitacora, usuario.nombre, "actualizar_necesidad", "Necesidad #{id_necesidad} -> #{nuevo_estado}", fecha)
          {:ok, transitada}
        end

      error ->
        error
    end
  end

  defp aplicar_filtros(lista, []), do: lista

  defp aplicar_filtros(lista, [{:zona, valor} | resto]) do
    lista
    |> Enum.filter(fn n -> String.downcase(n.codigo_zona) == String.downcase(to_string(valor)) end)
    |> aplicar_filtros(resto)
  end

  defp aplicar_filtros(lista, [{:prioridad, valor} | resto]) do
    lista
    |> Enum.filter(fn n -> to_string(n.prioridad) == to_string(valor) end)
    |> aplicar_filtros(resto)
  end

  defp aplicar_filtros(lista, [{:estado, valor} | resto]) do
    lista
    |> Enum.filter(fn n -> to_string(n.estado) == to_string(valor) end)
    |> aplicar_filtros(resto)
  end

  defp aplicar_filtros(lista, [_otro | resto]), do: aplicar_filtros(lista, resto)

  defp buscar_necesidad(repo, id) do
    {:ok, lista} = cargar_necesidades(repo)
    encontrada = Enum.find(lista, fn n -> String.upcase(n.id) == String.upcase(id) end)
    if encontrada, do: {:ok, encontrada}, else: {:error, :necesidad_no_encontrada}
  end

  defp obtener_repositorio(opts),
    do: Keyword.get(opts, :repositorio, Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo)

  defp obtener_bitacora(opts),
    do: Keyword.get(opts, :bitacora, Emergencias.Infraestructura.Procesos.BitacoraActividad)

  defp obtener_reloj(opts), do: Keyword.get(opts, :reloj, Reloj)

  defp cargar_necesidades(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:necesidades), else: {:ok, []}
  end

  defp guardar_necesidad(repo, nec) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:necesidades, nec), else: :ok
  end

  defp notificar_bitacora(bitacora, u, a, d, f) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(u, a, d, f)
    else
      :ok
    end
  end
end
