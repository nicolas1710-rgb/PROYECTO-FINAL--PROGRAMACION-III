defmodule Emergencias.Infraestructura.Procesos.GestorRecursos do
  @moduledoc """
  GenServer CLAVE para el control concurrente y transaccional de inventario.
  Serializa atómicamente asignaciones y transferencias previniendo sobreasignación y saldos negativos.
  Implementa el puerto de salida PuertoSalidaRecursos.
  """

  use GenServer

  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaRecursos

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{MovimientoInventario, Recurso}
  alias Emergencias.Dominio.Reglas.{Inventario, Validaciones}
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @doc """
  Iniciar el GenServer de recursos.
  """
  @spec iniciar(keyword()) :: {:ok, pid()} | {:error, any()}
  def iniciar(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  @doc """
  Callback exigido por OTP; delega a iniciar/1.
  """
  def start_link(opciones \\ []), do: iniciar(opciones)

  @doc """
  Especificación de supervisión OTP; delega a definir_especificacion/1.
  """
  def child_spec(opciones), do: definir_especificacion(opciones)

  @doc """
  Definir la especificación de supervisión para el gestor de recursos.
  """
  @spec definir_especificacion(keyword()) :: map()
  def definir_especificacion(opciones) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :iniciar, [opciones]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Registrar un nuevo recurso y su movimiento inicial en inventario.
  """
  @spec registrar_recurso(map(), String.t()) :: {:ok, Recurso.t()} | {:error, atom()}
  def registrar_recurso(params, usuario) do
    GenServer.call(__MODULE__, {:registrar, params, usuario})
  end

  @impl true
  @doc "Implementación del puerto: registrar recurso."
  @spec registrar(map(), String.t()) :: {:ok, Recurso.t()} | {:error, atom()}
  def registrar(params, usuario), do: registrar_recurso(params, usuario)

  @doc """
  Asignar de forma estrictamente atómica una cantidad de un recurso para atender una necesidad.
  """
  @spec asignar_recurso(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, atom()}
  def asignar_recurso(id_recurso, id_necesidad, cantidad, usuario) do
    GenServer.call(__MODULE__, {:asignar, id_recurso, id_necesidad, cantidad, usuario})
  end

  @impl true
  @doc "Implementación del puerto: asignar existencias."
  @spec asignar(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, atom()}
  def asignar(id_recurso, id_necesidad, cantidad, usuario) do
    asignar_recurso(id_recurso, id_necesidad, cantidad, usuario)
  end

  @doc """
  Transferir existencias entre dos recursos o centros de apoyo de forma atómica.
  """
  @spec transferir_recurso(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, {Recurso.t(), Recurso.t()}} | {:error, atom()}
  def transferir_recurso(id_origen, id_destino, cantidad, usuario) do
    GenServer.call(__MODULE__, {:transferir, id_origen, id_destino, cantidad, usuario})
  end

  @impl true
  @doc "Implementación del puerto: transferir existencias."
  @spec transferir(String.t(), String.t(), pos_integer(), String.t()) ::
          {:ok, {Recurso.t(), Recurso.t()}} | {:error, atom()}
  def transferir(id_origen, id_destino, cantidad, usuario) do
    transferir_recurso(id_origen, id_destino, cantidad, usuario)
  end

  @doc """
  Consultar un recurso por su código identificador.
  """
  @spec consultar_recurso(String.t()) :: {:ok, Recurso.t()} | {:error, :recurso_no_encontrado}
  def consultar_recurso(id_recurso) do
    GenServer.call(__MODULE__, {:consultar, id_recurso})
  end

  @impl true
  @doc "Implementación del puerto: consultar recurso."
  @spec consultar(String.t()) :: {:ok, Recurso.t()} | {:error, atom()}
  def consultar(id_recurso), do: consultar_recurso(id_recurso)

  @doc """
  Listar todos los recursos aplicando filtros.
  """
  @spec listar_recursos(keyword()) :: {:ok, list(Recurso.t())}
  def listar_recursos(filtros \\ []) do
    GenServer.call(__MODULE__, {:listar, filtros})
  end

  @impl true
  @doc "Implementación del puerto: listar recursos."
  @spec listar(keyword()) :: {:ok, list(Recurso.t())}
  def listar(filtros \\ []), do: listar_recursos(filtros)

  @impl true
  @doc "Implementación del puerto: listar movimientos de inventario."
  @spec listar_movimientos() :: {:ok, list(MovimientoInventario.t())}
  def listar_movimientos do
    GenServer.call(__MODULE__, :listar_movimientos)
  end

  @doc """
  Recargar recursos y movimientos desde persistencia en disco.
  """
  @spec recargar_datos() :: :ok
  def recargar_datos do
    GenServer.call(__MODULE__, :recargar)
  end

  # Callbacks OTP
  @impl true
  def init(opciones) do
    inicializar_gestor(opciones)
  end

  @impl true
  def handle_call(:recargar, _from, _estado) do
    {:ok, nuevo_estado} = inicializar_gestor([])
    {:reply, :ok, nuevo_estado}
  end

  @impl true
  def handle_call({:registrar, params, usuario}, _from, estado) do
    ejecutar_registro(params, usuario, estado)
  end

  @impl true
  def handle_call({:asignar, id_recurso, id_necesidad, cantidad, usuario}, _from, estado) do
    ejecutar_asignacion(id_recurso, id_necesidad, cantidad, usuario, estado)
  end

  @impl true
  def handle_call({:transferir, id_origen, id_destino, cantidad, usuario}, _from, estado) do
    ejecutar_transferencia(id_origen, id_destino, cantidad, usuario, estado)
  end

  @impl true
  def handle_call({:consultar, id_recurso}, _from, estado) do
    ejecutar_consulta(id_recurso, estado)
  end

  @impl true
  def handle_call({:listar, filtros}, _from, estado) do
    ejecutar_listado(filtros, estado)
  end

  @impl true
  def handle_call(:listar_movimientos, _from, estado) do
    ejecutar_listado_movimientos(estado)
  end

  # Funciones con verbos en infinitivo
  @doc """
  Inicializar el estado cargando recursos y movimientos desde persistencia.
  """
  @spec inicializar_gestor(keyword()) :: {:ok, map()}
  def inicializar_gestor(_opciones) do
    {:ok, recursos} = MotorPersistencia.cargar(:recursos)
    {:ok, movimientos} = MotorPersistencia.cargar(:movimientos)

    mapa_recursos = Map.new(recursos, fn r -> {String.upcase(r.id), r} end)
    {:ok, %{recursos: mapa_recursos, total_movimientos: length(movimientos)}}
  end

  @doc """
  Ejecutar el registro seguro de un recurso.
  """
  @spec ejecutar_registro(map(), String.t(), map()) ::
          {:reply, {:ok, Recurso.t()} | {:error, atom()}, map()}
  def ejecutar_registro(params, usuario, estado) do
    with {:ok, validados} <- Validaciones.validar_entrada_recurso(params) do
      nuevo_id = Map.get(params, :id) || GeneradorId.formatear_id(:recurso, map_size(estado.recursos) + 1)
      id_mov = GeneradorId.formatear_id(:movimiento, estado.total_movimientos + 1)
      fecha = Reloj.obtener_fecha_actual()
      nombre = Map.get(validados, :nombre, validados.tipo)

      {:ok, nuevo_rec} =
        Recurso.construir(%{
          id: nuevo_id,
          nombre: nombre,
          tipo: validados.tipo,
          unidad_medida: validados.unidad_medida,
          cantidad_total: validados.cantidad_total,
          cantidad_disponible: validados.cantidad_total,
          cantidad_reservada: 0,
          codigo_zona: validados.codigo_zona,
          fecha_registro: fecha
        })

      {:ok, mov} =
        MovimientoInventario.construir(%{
          id: id_mov,
          codigo_recurso: nuevo_id,
          tipo_movimiento: :entrada,
          cantidad: validados.cantidad_total,
          origen: "Ingreso Inicial",
          destino: validados.codigo_zona,
          fecha: fecha,
          usuario_responsable: usuario
        })

      MotorPersistencia.guardar(:recursos, nuevo_rec)
      MotorPersistencia.anexar(:movimientos, mov)

      nuevos = Map.put(estado.recursos, String.upcase(nuevo_id), nuevo_rec)
      {:reply, {:ok, nuevo_rec}, %{estado | recursos: nuevos, total_movimientos: estado.total_movimientos + 1}}
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar la asignación atómica evitando carreras y saldos negativos.
  """
  @spec ejecutar_asignacion(String.t(), String.t(), pos_integer(), String.t(), map()) ::
          {:reply, {:ok, {Recurso.t(), MovimientoInventario.t()}} | {:error, atom()}, map()}
  def ejecutar_asignacion(id_recurso, id_necesidad, cantidad, usuario, estado) do
    clave = String.upcase(id_recurso)

    case Map.get(estado.recursos, clave) do
      nil ->
        {:reply, {:error, :recurso_no_encontrado}, estado}

      %Recurso{} = actual ->
        fecha = Reloj.obtener_fecha_actual()
        id_mov = GeneradorId.formatear_id(:movimiento, estado.total_movimientos + 1)

        case Inventario.asignar(actual, cantidad, id_mov, id_necesidad, usuario, fecha) do
          {:ok, {recurso_act, mov}} ->
            MotorPersistencia.guardar(:recursos, recurso_act)
            MotorPersistencia.anexar(:movimientos, mov)

            nuevos = Map.put(estado.recursos, clave, recurso_act)
            nuevo_estado = %{estado | recursos: nuevos, total_movimientos: estado.total_movimientos + 1}
            {:reply, {:ok, {recurso_act, mov}}, nuevo_estado}

          {:error, razon} ->
            {:reply, {:error, razon}, estado}
        end
    end
  end

  @doc """
  Ejecutar la transferencia atómica entre recursos o centros de apoyo territorial.
  """
  @spec ejecutar_transferencia(String.t(), String.t(), pos_integer(), String.t(), map()) ::
          {:reply, {:ok, {Recurso.t(), Recurso.t()}} | {:error, atom()}, map()}
  def ejecutar_transferencia(id_origen, id_destino, cantidad, usuario, estado) do
    c_orig = String.upcase(id_origen)
    c_dest = String.upcase(id_destino)

    r_orig = Map.get(estado.recursos, c_orig)

    if is_nil(r_orig) do
      {:reply, {:error, :recurso_origen_no_encontrado}, estado}
    else
      {r_dest, estado_actualizado} = resolver_destino_transferencia(c_dest, r_orig, estado)
      fecha = Reloj.obtener_fecha_actual()
      id_m1 = GeneradorId.formatear_id(:movimiento, estado_actualizado.total_movimientos + 1)
      id_m2 = GeneradorId.formatear_id(:movimiento, estado_actualizado.total_movimientos + 2)

      case Inventario.transferir(r_orig, r_dest, cantidad, {id_m1, id_m2}, usuario, fecha) do
        {:ok, {o_act, d_act, m1, m2}} ->
          MotorPersistencia.guardar(:recursos, o_act)
          MotorPersistencia.guardar(:recursos, d_act)
          MotorPersistencia.anexar(:movimientos, m1)
          MotorPersistencia.anexar(:movimientos, m2)

          nuevos =
            estado_actualizado.recursos
            |> Map.put(c_orig, o_act)
            |> Map.put(String.upcase(d_act.id), d_act)

          nuevo_estado = %{
            estado_actualizado
            | recursos: nuevos,
              total_movimientos: estado_actualizado.total_movimientos + 2
          }

          {:reply, {:ok, {o_act, d_act}}, nuevo_estado}

        {:error, razon} ->
          {:reply, {:error, razon}, estado}
      end
    end
  end

  defp resolver_destino_transferencia(c_dest, r_orig, estado) do
    case Map.get(estado.recursos, c_dest) do
      %Recurso{} = directo ->
        {directo, estado}

      nil ->
        # Buscar en la zona destino un recurso compatible
        existente =
          Enum.find(Map.values(estado.recursos), fn r ->
            String.upcase(r.codigo_zona) == c_dest and
              String.downcase(r.tipo) == String.downcase(r_orig.tipo)
          end)

        if existente != nil do
          {existente, estado}
        else
          # Crear recurso nuevo en el centro destino
          nuevo_id = GeneradorId.formatear_id(:recurso, map_size(estado.recursos) + 1)
          fecha = Reloj.obtener_fecha_actual()

          {:ok, nuevo} =
            Recurso.construir(%{
              id: nuevo_id,
              nombre: r_orig.nombre,
              tipo: r_orig.tipo,
              unidad_medida: r_orig.unidad_medida,
              cantidad_total: 0,
              cantidad_disponible: 0,
              cantidad_reservada: 0,
              codigo_zona: c_dest,
              fecha_registro: fecha
            })

          {nuevo, %{estado | recursos: Map.put(estado.recursos, String.upcase(nuevo_id), nuevo)}}
        end
    end
  end

  @doc """
  Responder la lista de movimientos registrados en persistencia.
  """
  @spec ejecutar_listado_movimientos(map()) :: {:reply, {:ok, list(MovimientoInventario.t())}, map()}
  def ejecutar_listado_movimientos(estado) do
    {:ok, movimientos} = MotorPersistencia.cargar(:movimientos)
    {:reply, {:ok, movimientos}, estado}
  end

  @doc """
  Ejecutar la consulta de un recurso.
  """
  @spec ejecutar_consulta(String.t(), map()) ::
          {:reply, {:ok, Recurso.t()} | {:error, :recurso_no_encontrado}, map()}
  def ejecutar_consulta(id_recurso, estado) do
    case Map.get(estado.recursos, String.upcase(id_recurso)) do
      %Recurso{} = r -> {:reply, {:ok, r}, estado}
      nil -> {:reply, {:error, :recurso_no_encontrado}, estado}
    end
  end

  @doc """
  Ejecutar el listado de recursos con filtros.
  """
  @spec ejecutar_listado(keyword(), map()) :: {:reply, {:ok, list(Recurso.t())}, map()}
  def ejecutar_listado(filtros, estado) do
    lista = Map.values(estado.recursos)
    resultado = filtrar_lista(lista, filtros)
    {:reply, {:ok, resultado}, estado}
  end

  defp filtrar_lista(lista, []), do: lista

  defp filtrar_lista(lista, [{:zona, z} | resto]) do
    lista
    |> Enum.filter(fn r -> String.downcase(r.codigo_zona) == String.downcase(to_string(z)) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [{:tipo, t} | resto]) do
    lista
    |> Enum.filter(fn r -> String.downcase(r.tipo) == String.downcase(to_string(t)) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [_ | resto]), do: filtrar_lista(lista, resto)
end
