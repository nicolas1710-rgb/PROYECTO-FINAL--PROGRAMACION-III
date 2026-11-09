defmodule Emergencias.Aplicacion.CasosUso.GestionarRecursos do
  @moduledoc """
  Caso de uso para inventario, asignación atómica a necesidades y transferencias entre zonas.
  Garantiza la vinculación transaccional entre recursos y necesidades humanitarias.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoRecursos

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{MovimientoInventario, Necesidad, Recurso, Usuario}
  alias Emergencias.Dominio.Reglas.{Inventario, Permisos, Validaciones}

  @impl true
  @doc """
  Registrar un nuevo lote de recursos en inventario.
  """
  @spec registrar_recurso(map(), Usuario.t(), keyword()) :: {:ok, Recurso.t()} | {:error, atom()}
  def registrar_recurso(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_recurso) do
      puerto_rec = resolver_puerto(opciones, :puerto_recursos, :puerto_recursos)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_rec != nil and function_exported?(puerto_rec, :registrar, 2) ->
          case puerto_rec.registrar(params, usuario.nombre) do
            {:ok, rec} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_recurso", "Recurso #{rec.id} ingresado", fecha)
              {:ok, rec}

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
  Listar recursos con filtros opcionales de zona y tipo.
  """
  @spec listar_recursos(keyword(), Usuario.t(), keyword()) ::
          {:ok, list(Recurso.t())} | {:error, atom()}
  def listar_recursos(filtros, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :listar_recursos) do
      puerto_rec = resolver_puerto(opciones, :puerto_recursos, :puerto_recursos)

      cond do
        puerto_rec != nil and function_exported?(puerto_rec, :listar, 1) ->
          puerto_rec.listar(filtros)

        true ->
          repositorio = Keyword.get(opciones, :repositorio)
          {:ok, lista} = cargar_recursos(repositorio)
          {:ok, filtrar_recursos(lista, filtros)}
      end
    end
  end

  @impl true
  @doc """
  Asignar recursos de manera atómica para atender una necesidad.
  Valida primero la necesidad (existencia, estado y cantidad pendiente) antes de modificar stock.
  """
  @spec asignar_recurso(String.t(), String.t(), pos_integer(), Usuario.t(), keyword()) ::
          {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, atom()}
  def asignar_recurso(id_recurso, id_necesidad, cantidad, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :asignar_recurso),
         {:ok, cant_valida} <- Validaciones.validar_cantidad_positiva(cantidad) do
      puerto_rec = resolver_puerto(opciones, :puerto_recursos, :puerto_recursos)
      puerto_nec = resolver_puerto(opciones, :puerto_necesidades, :puerto_necesidades)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_rec != nil and function_exported?(puerto_rec, :asignar, 4) and
        puerto_nec != nil and function_exported?(puerto_nec, :consultar, 1) ->
          with {:ok, necesidad} <- puerto_nec.consultar(id_necesidad),
               :ok <- validar_necesidad_abierta(necesidad),
               :ok <- validar_saldo_pendiente(necesidad, cant_valida),
               {:ok, recurso} <- puerto_rec.consultar(id_recurso),
               :ok <- validar_compatibilidad_recurso(recurso, necesidad),
               {:ok, {rec_act, mov}} <- puerto_rec.asignar(id_recurso, id_necesidad, cant_valida, usuario.nombre) do
            case puerto_nec.asignar_suministro(id_necesidad, cant_valida, usuario.nombre) do
              {:ok, _nec_act} ->
                notificar_bitacora(puerto_bitacora, usuario.nombre, "asignar_recurso", "Asignados #{cant_valida} de #{id_recurso} a #{id_necesidad}", fecha)
                {:ok, {rec_act, mov}}

              {:error, razon} ->
                # Revertir asignación descontada
                _ = puerto_rec.registrar(%{id: rec_act.id, tipo: rec_act.tipo, unidad_medida: rec_act.unidad_medida, cantidad_total: cant_valida, codigo_zona: rec_act.codigo_zona}, usuario.nombre)
                {:error, razon}
            end
          end

        true ->
          ejecutar_asignacion_directa(id_recurso, id_necesidad, cant_valida, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Transferir existencias entre dos recursos o centros de apoyo de forma atómica.
  """
  @spec transferir_recurso(String.t(), String.t(), pos_integer(), Usuario.t(), keyword()) ::
          {:ok, {Recurso.t(), Recurso.t()}} | {:error, atom()}
  def transferir_recurso(id_origen, id_destino, cantidad, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :transferir_recurso),
         {:ok, cant_valida} <- Validaciones.validar_cantidad_positiva(cantidad) do
      puerto_rec = resolver_puerto(opciones, :puerto_recursos, :puerto_recursos)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_rec != nil and function_exported?(puerto_rec, :transferir, 4) ->
          case puerto_rec.transferir(id_origen, id_destino, cant_valida, usuario.nombre) do
            {:ok, {o_act, d_act}} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "transferir_recurso", "#{cant_valida} de #{id_origen} a #{id_destino}", fecha)
              {:ok, {o_act, d_act}}

            error ->
              error
          end

        true ->
          ejecutar_transferencia_directa(id_origen, id_destino, cant_valida, usuario, opciones)
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

  defp validar_necesidad_abierta(%Necesidad{estado: :atendida}), do: {:error, :necesidad_ya_atendida}
  defp validar_necesidad_abierta(%Necesidad{estado: :cancelada}), do: {:error, :necesidad_cancelada}
  defp validar_necesidad_abierta(%Necesidad{}), do: :ok

  defp validar_saldo_pendiente(%Necesidad{} = nec, cantidad) do
    pendiente = nec.cantidad_solicitada - nec.cantidad_asignada
    cond do
      pendiente <= 0 -> {:error, :necesidad_ya_atendida}
      cantidad > pendiente -> {:error, :cantidad_excede_necesidad}
      true -> :ok
    end
  end

  defp validar_compatibilidad_recurso(%Recurso{} = rec, %Necesidad{} = nec) do
    if String.downcase(String.trim(rec.tipo)) == String.downcase(String.trim(nec.tipo_recurso)) do
      :ok
    else
      {:error, :tipo_recurso_incompatible}
    end
  end

  defp ejecutar_registro_directo(params, usuario, opciones) do
    with {:ok, datos} <- Validaciones.validar_entrada_recurso(params) do
      repositorio = Keyword.get(opciones, :repositorio)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_recursos(repositorio)
      nuevo_id = Map.get(params, :id) || GeneradorId.formatear_id(:recurso, length(existentes) + 1)
      nombre = Map.get(datos, :nombre, datos.tipo)

      {:ok, nuevo_recurso} =
        Recurso.construir(%{
          id: nuevo_id,
          nombre: nombre,
          tipo: datos.tipo,
          unidad_medida: datos.unidad_medida,
          cantidad_total: datos.cantidad_total,
          cantidad_disponible: datos.cantidad_total,
          cantidad_reservada: 0,
          codigo_zona: datos.codigo_zona,
          fecha_registro: fecha
        })

      {:ok, existentes_movs} = cargar_movimientos(repositorio)
      id_mov = GeneradorId.formatear_id(:movimiento, length(existentes_movs) + 1)

      {:ok, mov_inicial} =
        MovimientoInventario.construir(%{
          id: id_mov,
          codigo_recurso: nuevo_id,
          tipo_movimiento: :entrada,
          cantidad: datos.cantidad_total,
          origen: "Ingreso Inicial",
          destino: datos.codigo_zona,
          fecha: fecha,
          usuario_responsable: usuario.nombre
        })

      guardar_recurso(repositorio, nuevo_recurso)
      guardar_movimiento(repositorio, mov_inicial)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_recurso", "Recurso #{nuevo_id} ingresado", fecha)
      {:ok, nuevo_recurso}
    end
  end

  defp ejecutar_asignacion_directa(id_recurso, id_necesidad, cantidad, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, necesidad} <- buscar_necesidad(repositorio, id_necesidad),
         :ok <- validar_necesidad_abierta(necesidad),
         :ok <- validar_saldo_pendiente(necesidad, cantidad),
         {:ok, recurso} <- buscar_recurso(repositorio, id_recurso),
         :ok <- validar_compatibilidad_recurso(recurso, necesidad) do
      {:ok, movs} = cargar_movimientos(repositorio)
      id_mov = GeneradorId.formatear_id(:movimiento, length(movs) + 1)

      with {:ok, {rec_act, mov}} <-
             Inventario.asignar(recurso, cantidad, id_mov, id_necesidad, usuario.nombre, fecha) do
        nueva_asig = necesidad.cantidad_asignada + cantidad
        nuevo_est = if nueva_asig >= necesidad.cantidad_solicitada, do: :atendida, else: :asignada
        evento = %{fecha: fecha, estado_anterior: necesidad.estado, estado_nuevo: nuevo_est, usuario: usuario.nombre}
        nec_act = %{necesidad | cantidad_asignada: nueva_asig, estado: nuevo_est, historial: [evento | necesidad.historial]}

        guardar_recurso(repositorio, rec_act)
        guardar_necesidad(repositorio, nec_act)
        guardar_movimiento(repositorio, mov)
        notificar_bitacora(puerto_bitacora, usuario.nombre, "asignar_recurso", "#{cantidad} de #{id_recurso} a #{id_necesidad}", fecha)
        {:ok, {rec_act, mov}}
      end
    end
  end

  defp ejecutar_transferencia_directa(id_origen, id_destino, cantidad, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, origen} <- buscar_recurso(repositorio, id_origen),
         {:ok, destino} <- buscar_o_crear_destino_directo(repositorio, id_destino, origen, fecha) do
      {:ok, movs} = cargar_movimientos(repositorio)
      id_m1 = GeneradorId.formatear_id(:movimiento, length(movs) + 1)
      id_m2 = GeneradorId.formatear_id(:movimiento, length(movs) + 2)

      with {:ok, {o_act, d_act, m1, m2}} <-
             Inventario.transferir(origen, destino, cantidad, {id_m1, id_m2}, usuario.nombre, fecha) do
        guardar_recurso(repositorio, o_act)
        guardar_recurso(repositorio, d_act)
        guardar_movimiento(repositorio, m1)
        guardar_movimiento(repositorio, m2)
        notificar_bitacora(puerto_bitacora, usuario.nombre, "transferir_recurso", "#{cantidad} de #{id_origen} a #{id_destino}", fecha)
        {:ok, {o_act, d_act}}
      end
    end
  end

  defp buscar_o_crear_destino_directo(repositorio, id_destino, origen, fecha) do
    case buscar_recurso(repositorio, id_destino) do
      {:ok, dest} ->
        {:ok, dest}

      {:error, :recurso_no_encontrado} ->
        # Buscar por zona
        {:ok, lista} = cargar_recursos(repositorio)
        c_dest = String.upcase(id_destino)
        existente = Enum.find(lista, fn r -> String.upcase(r.codigo_zona) == c_dest and String.downcase(r.tipo) == String.downcase(origen.tipo) end)

        if existente != nil do
          {:ok, existente}
        else
          nuevo_id = GeneradorId.formatear_id(:recurso, length(lista) + 1)
          {:ok, nuevo} =
            Recurso.construir(%{
              id: nuevo_id,
              nombre: origen.nombre,
              tipo: origen.tipo,
              unidad_medida: origen.unidad_medida,
              cantidad_total: 0,
              cantidad_disponible: 0,
              cantidad_reservada: 0,
              codigo_zona: c_dest,
              fecha_registro: fecha
            })
          guardar_recurso(repositorio, nuevo)
          {:ok, nuevo}
        end
    end
  end

  defp filtrar_recursos(lista, []), do: lista

  defp filtrar_recursos(lista, [{:zona, valor} | resto]) do
    lista
    |> Enum.filter(fn r -> String.downcase(r.codigo_zona) == String.downcase(to_string(valor)) end)
    |> filtrar_recursos(resto)
  end

  defp filtrar_recursos(lista, [{:tipo, valor} | resto]) do
    lista
    |> Enum.filter(fn r -> String.downcase(r.tipo) == String.downcase(to_string(valor)) end)
    |> filtrar_recursos(resto)
  end

  defp filtrar_recursos(lista, [_ | resto]), do: filtrar_recursos(lista, resto)

  defp buscar_recurso(repo, id) do
    {:ok, lista} = cargar_recursos(repo)
    encontrado = Enum.find(lista, fn r -> String.upcase(r.id) == String.upcase(id) end)
    if encontrado, do: {:ok, encontrado}, else: {:error, :recurso_no_encontrado}
  end

  defp buscar_necesidad(repo, id) do
    {:ok, lista} = cargar_necesidades(repo)
    encontrada = Enum.find(lista, fn n -> String.upcase(n.id) == String.upcase(id) end)
    if encontrada, do: {:ok, encontrada}, else: {:error, :necesidad_no_encontrada}
  end

  defp cargar_recursos(nil), do: {:ok, []}
  defp cargar_recursos(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:recursos), else: {:ok, []}
  end

  defp guardar_recurso(nil, _r), do: :ok
  defp guardar_recurso(repo, r) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:recursos, r), else: :ok
  end

  defp cargar_necesidades(nil), do: {:ok, []}
  defp cargar_necesidades(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:necesidades), else: {:ok, []}
  end

  defp guardar_necesidad(nil, _n), do: :ok
  defp guardar_necesidad(repo, n) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:necesidades, n), else: :ok
  end

  defp cargar_movimientos(nil), do: {:ok, []}
  defp cargar_movimientos(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:movimientos), else: {:ok, []}
  end

  defp guardar_movimiento(nil, _m), do: :ok
  defp guardar_movimiento(repo, m) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:movimientos, m), else: :ok
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
