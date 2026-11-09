defmodule Emergencias.Aplicacion.CasosUso.GestionarNecesidades do
  @moduledoc """
  Caso de uso para registrar, consultar y actualizar el estado de necesidades humanitarias.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoNecesidades

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Necesidad, Usuario}
  alias Emergencias.Dominio.Reglas.{Permisos, TransicionesEstado, Validaciones}

  @impl true
  @doc """
  Registrar una nueva necesidad reportada para una zona.
  """
  @spec registrar_necesidad(map(), Usuario.t(), keyword()) :: {:ok, Necesidad.t()} | {:error, atom()}
  def registrar_necesidad(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_necesidad) do
      puerto_nec = resolver_puerto(opciones, :puerto_necesidades, :puerto_necesidades)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_nec != nil and function_exported?(puerto_nec, :registrar, 2) ->
          case puerto_nec.registrar(params, usuario.nombre) do
            {:ok, nec} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_necesidad", "Necesidad #{nec.id} reportada", fecha)
              {:ok, nec}

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
  Listar necesidades aplicando filtros opcionales de zona, prioridad o estado.
  """
  @spec listar_necesidades(keyword(), Usuario.t(), keyword()) ::
          {:ok, list(Necesidad.t())} | {:error, atom()}
  def listar_necesidades(filtros, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :listar_necesidades) do
      puerto_nec = resolver_puerto(opciones, :puerto_necesidades, :puerto_necesidades)

      cond do
        puerto_nec != nil and function_exported?(puerto_nec, :listar, 1) ->
          puerto_nec.listar(filtros)

        true ->
          repositorio = Keyword.get(opciones, :repositorio)
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
      puerto_nec = resolver_puerto(opciones, :puerto_necesidades, :puerto_necesidades)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_nec != nil and function_exported?(puerto_nec, :actualizar_estado, 3) ->
          case puerto_nec.actualizar_estado(id_necesidad, nuevo_estado, usuario.nombre) do
            {:ok, transitada} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "actualizar_necesidad", "Necesidad #{id_necesidad} -> #{nuevo_estado}", fecha)
              {:ok, transitada}

            error ->
              error
          end

        true ->
          ejecutar_actualizacion_directa(id_necesidad, nuevo_estado, usuario, opciones)
      end
    end
  end

  @doc """
  Consultar una necesidad por su identificador único.
  """
  @spec consultar_necesidad(String.t(), Usuario.t(), keyword()) ::
          {:ok, Necesidad.t()} | {:error, atom()}
  def consultar_necesidad(id_necesidad, %Usuario{}, opciones \\ []) do
    puerto_nec = resolver_puerto(opciones, :puerto_necesidades, :puerto_necesidades)

    cond do
      puerto_nec != nil and function_exported?(puerto_nec, :consultar, 1) ->
        puerto_nec.consultar(id_necesidad)

      true ->
        repositorio = Keyword.get(opciones, :repositorio)
        buscar_necesidad(repositorio, id_necesidad)
    end
  end

  @doc """
  Asignar suministros a una necesidad incrementando cantidad asignada y actualizando su estado.
  """
  @spec asignar_suministro(String.t(), pos_integer(), Usuario.t(), keyword()) ::
          {:ok, Necesidad.t()} | {:error, atom()}
  def asignar_suministro(id_necesidad, cantidad, %Usuario{} = usuario, opciones \\ []) do
    puerto_nec = resolver_puerto(opciones, :puerto_necesidades, :puerto_necesidades)

    cond do
      puerto_nec != nil and function_exported?(puerto_nec, :asignar_suministro, 3) ->
        puerto_nec.asignar_suministro(id_necesidad, cantidad, usuario.nombre)

      true ->
        ejecutar_asignacion_suministro_directa(id_necesidad, cantidad, usuario, opciones)
    end
  end

  defp resolver_puerto(opciones, clave, config_key) do
    cond do
      Keyword.has_key?(opciones, clave) -> Keyword.get(opciones, clave)
      Keyword.has_key?(opciones, :repositorio) -> nil
      true -> Application.get_env(:emergencias, config_key)
    end
  end

  defp ejecutar_registro_directo(params, usuario, opciones) do
    with {:ok, datos_validados} <- Validaciones.validar_entrada_necesidad(params) do
      repositorio = Keyword.get(opciones, :repositorio)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_necesidades(repositorio)
      nuevo_id = GeneradorId.formatear_id(:necesidad, length(existentes) + 1)

      {:ok, nueva_nec} =
        Necesidad.construir(%{
          id: nuevo_id,
          codigo_zona: datos_validados.codigo_zona,
          tipo_recurso: datos_validados.tipo_recurso,
          cantidad_solicitada: datos_validados.cantidad_solicitada,
          cantidad_asignada: 0,
          prioridad: datos_validados.prioridad,
          estado: :pendiente,
          fecha_registro: fecha,
          usuario_reporta: usuario.nombre,
          descripcion: Map.get(datos_validados, :descripcion, "")
        })

      guardar_necesidad(repositorio, nueva_nec)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_necesidad", "Necesidad #{nuevo_id} reportada", fecha)
      {:ok, nueva_nec}
    end
  end

  defp ejecutar_actualizacion_directa(id_necesidad, nuevo_estado, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    case buscar_necesidad(repositorio, id_necesidad) do
      {:ok, %Necesidad{} = actual} ->
        with {:ok, transitada} <- TransicionesEstado.transitar_necesidad(actual, nuevo_estado, usuario.nombre, fecha) do
          guardar_necesidad(repositorio, transitada)
          notificar_bitacora(puerto_bitacora, usuario.nombre, "actualizar_necesidad", "Necesidad #{id_necesidad} -> #{nuevo_estado}", fecha)
          {:ok, transitada}
        end

      error ->
        error
    end
  end

  defp ejecutar_asignacion_suministro_directa(id_necesidad, cantidad, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    case buscar_necesidad(repositorio, id_necesidad) do
      {:ok, %Necesidad{} = actual} ->
        nueva_asignada = actual.cantidad_asignada + cantidad
        nuevo_estado = if nueva_asignada >= actual.cantidad_solicitada, do: :atendida, else: :asignada
        evento = %{fecha: fecha, estado_anterior: actual.estado, estado_nuevo: nuevo_estado, usuario: usuario.nombre}
        actualizada = %{actual | cantidad_asignada: nueva_asignada, estado: nuevo_estado, historial: [evento | actual.historial]}
        guardar_necesidad(repositorio, actualizada)
        {:ok, actualizada}

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

  defp cargar_necesidades(nil), do: {:ok, []}
  defp cargar_necesidades(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:necesidades), else: {:ok, []}
  end

  defp guardar_necesidad(nil, _nec), do: :ok
  defp guardar_necesidad(repo, nec) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:necesidades, nec), else: :ok
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
