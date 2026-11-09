defmodule Emergencias.Infraestructura.Procesos.GestorLogistica do
  @moduledoc "GenServer unificado para inventario de recursos, necesidades y movimientos atomicos."
  use GenServer
  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoLogistica

  alias Emergencias.Dominio.Modelos.{Necesidad, Recurso}
  alias Emergencias.Dominio.Reglas.{Asignacion, Estados, Identificadores, Inventario}
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  def iniciar(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def start_link(opts \\ []), do: iniciar(opts)
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :iniciar, [opts]}, type: :worker}

  @impl true
  def registrar_recurso(p), do: GenServer.call(__MODULE__, {:registrar_recurso, p})
  @impl true
  def registrar_necesidad(p), do: GenServer.call(__MODULE__, {:registrar_necesidad, p})
  @impl true
  def asignar(r_id, n_id, cant, u, fecha), do: GenServer.call(__MODULE__, {:asignar, r_id, n_id, cant, u, fecha})
  @impl true
  def transferir(cod, o_ub, d_ub, cant, u, fecha), do: GenServer.call(__MODULE__, {:transferir, cod, o_ub, d_ub, cant, u, fecha})
  @impl true
  def actualizar_necesidad(n_id, est, u, fecha), do: GenServer.call(__MODULE__, {:actualizar_necesidad, n_id, est, u, fecha})
  @impl true
  def listar_recursos, do: GenServer.call(__MODULE__, :listar_recursos)
  @impl true
  def listar_necesidades, do: GenServer.call(__MODULE__, :listar_necesidades)
  @impl true
  def listar_movimientos, do: GenServer.call(__MODULE__, :listar_movimientos)
  @impl true
  def consultar_recurso(id), do: GenServer.call(__MODULE__, {:consultar_recurso, id})
  @impl true
  def consultar_necesidad(id), do: GenServer.call(__MODULE__, {:consultar_necesidad, id})

  @impl true
  def init(_opts) do
    recs = AlmacenArchivo.cargar(:recursos) |> Map.new(fn r -> {r.id, r} end)
    necs = AlmacenArchivo.cargar(:necesidades) |> Map.new(fn n -> {n.id, n} end)
    movs = AlmacenArchivo.cargar(:movimientos)
    {:ok, %{recursos: recs, necesidades: necs, movimientos: movs}}
  end

  @impl true
  def handle_call({:registrar_recurso, p}, _from, st), do: ejecutar_registro_recurso(p, st)
  @impl true
  def handle_call({:registrar_necesidad, p}, _from, st), do: ejecutar_registro_necesidad(p, st)
  @impl true
  def handle_call({:asignar, r_id, n_id, cant, u, fecha}, _from, st), do: ejecutar_asignacion(r_id, n_id, cant, u, fecha, st)
  @impl true
  def handle_call({:transferir, cod, o_ub, d_ub, cant, u, fecha}, _from, st), do: ejecutar_transferencia(cod, o_ub, d_ub, cant, u, fecha, st)
  @impl true
  def handle_call({:actualizar_necesidad, id, est, u, fecha}, _from, st), do: ejecutar_actualizacion_necesidad(id, est, u, fecha, st)
  @impl true
  def handle_call(:listar_recursos, _from, st), do: {:reply, Map.values(st.recursos), st}
  @impl true
  def handle_call(:listar_necesidades, _from, st), do: {:reply, Map.values(st.necesidades), st}
  @impl true
  def handle_call(:listar_movimientos, _from, st), do: {:reply, st.movimientos, st}
  @impl true
  def handle_call({:consultar_recurso, id}, _from, st), do: {:reply, Map.fetch(st.recursos, id), st}
  @impl true
  def handle_call({:consultar_necesidad, id}, _from, st), do: {:reply, Map.fetch(st.necesidades, id), st}

  defp ejecutar_registro_recurso(p, st) do
    id = Map.get(p, :id) || Map.get(p, :codigo) || Identificadores.generar("R", map_size(st.recursos))
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    {:ok, r} = Recurso.construir(Map.merge(p, %{id: id, fecha_registro: fecha}))
    nuevo_st = %{st | recursos: Map.put(st.recursos, id, r)}
    AlmacenArchivo.guardar(:recursos, Map.values(nuevo_st.recursos))
    {:reply, {:ok, r}, nuevo_st}
  end

  defp ejecutar_registro_necesidad(p, st) do
    id = Map.get(p, :id) || Identificadores.generar("N", map_size(st.necesidades))
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    {:ok, n} = Necesidad.construir(Map.merge(p, %{id: id, fecha_registro: fecha}))
    nuevo_st = %{st | necesidades: Map.put(st.necesidades, id, n)}
    AlmacenArchivo.guardar(:necesidades, Map.values(nuevo_st.necesidades))
    {:reply, {:ok, n}, nuevo_st}
  end

  defp ejecutar_asignacion(r_id, n_id, cant, u, fecha, st) do
    case Asignacion.asignar(st, r_id, n_id, cant, u, fecha) do
      {:ok, nuevo_st, datos} ->
        AlmacenArchivo.guardar(:recursos, Map.values(nuevo_st.recursos))
        AlmacenArchivo.guardar(:necesidades, Map.values(nuevo_st.necesidades))
        AlmacenArchivo.guardar(:movimientos, nuevo_st.movimientos)
        {:reply, {:ok, datos}, nuevo_st}
      error -> {:reply, error, st}
    end
  end

  defp ejecutar_transferencia(cod, o_ub, d_ub, cant, u, fecha, st) do
    origen = Enum.find(Map.values(st.recursos), fn r -> (r.id == cod or r.nombre == cod) and r.ubicacion == o_ub end) || Map.get(st.recursos, cod)
    destino = Enum.find(Map.values(st.recursos), fn r -> (r.id == cod or r.nombre == cod) and r.ubicacion == d_ub end) || Map.get(st.recursos, d_ub)

    cond do
      is_nil(origen) -> {:reply, {:error, :recurso_no_encontrado}, st}
      true ->
        dest_final = destino || %Recurso{id: Identificadores.generar("R", map_size(st.recursos)), nombre: origen.nombre, categoria: origen.categoria, unidad_medida: origen.unidad_medida, cantidad_total: 0, cantidad_disponible: 0, ubicacion: d_ub, fecha_registro: fecha}
        case Inventario.transferir(origen, dest_final, cant, u, fecha) do
          {:ok, o_act, d_act, [m1, m2]} ->
            recs = st.recursos |> Map.put(o_act.id, o_act) |> Map.put(d_act.id, d_act)
            nuevo_st = %{st | recursos: recs, movimientos: [m2, m1 | st.movimientos]}
            AlmacenArchivo.guardar(:recursos, Map.values(nuevo_st.recursos))
            AlmacenArchivo.guardar(:movimientos, nuevo_st.movimientos)
            {:reply, {:ok, {o_act, d_act}}, nuevo_st}
          error -> {:reply, error, st}
        end
    end
  end

  defp ejecutar_actualizacion_necesidad(id, est, u, fecha, st) do
    case Map.get(st.necesidades, id) do
      nil -> {:reply, {:error, :necesidad_no_encontrada}, st}
      nec ->
        case Estados.transitar(nec, est, u, fecha) do
          {:ok, nec_act} ->
            nuevo_st = %{st | necesidades: Map.put(st.necesidades, id, nec_act)}
            AlmacenArchivo.guardar(:necesidades, Map.values(nuevo_st.necesidades))
            {:reply, {:ok, nec_act}, nuevo_st}
          error -> {:reply, error, st}
        end
    end
  end
end
