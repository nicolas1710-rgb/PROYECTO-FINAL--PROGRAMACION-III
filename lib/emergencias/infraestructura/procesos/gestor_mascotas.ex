defmodule Emergencias.Infraestructura.Procesos.GestorMascotas do
  @moduledoc "GenServer para reportes, emparejamiento y resolucion de mascotas."
  use GenServer
  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoMascotas

  alias Emergencias.Dominio.Modelos.Mascota
  alias Emergencias.Dominio.Reglas.{Estados, Identificadores}
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  def iniciar(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def start_link(opts \\ []), do: iniciar(opts)
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :iniciar, [opts]}, type: :worker}

  @impl true
  def reportar(p), do: GenServer.call(__MODULE__, {:reportar, p})
  @impl true
  def listar, do: GenServer.call(__MODULE__, :listar)
  @impl true
  def consultar(id), do: GenServer.call(__MODULE__, {:consultar, id})
  @impl true
  def confirmar_coincidencia(id_p, id_e, u, fecha), do: GenServer.call(__MODULE__, {:confirmar_coincidencia, id_p, id_e, u, fecha})
  @impl true
  def actualizar_estado(id, est, u, fecha), do: GenServer.call(__MODULE__, {:actualizar_estado, id, est, u, fecha})

  @impl true
  def init(_opts) do
    lista = AlmacenArchivo.cargar(:mascotas)
    {:ok, Map.new(lista, fn m -> {m.id, m} end)}
  end

  @impl true
  def handle_call({:reportar, p}, _from, st), do: ejecutar_reporte(p, st)
  @impl true
  def handle_call(:listar, _from, st), do: {:reply, Map.values(st), st}
  @impl true
  def handle_call({:consultar, id}, _from, st), do: {:reply, Map.fetch(st, id), st}
  @impl true
  def handle_call({:confirmar_coincidencia, id_p, id_e, u, f}, _from, st), do: ejecutar_confirmacion(id_p, id_e, u, f, st)
  @impl true
  def handle_call({:actualizar_estado, id, est, u, f}, _from, st), do: ejecutar_actualizacion(id, est, u, f, st)

  defp ejecutar_reporte(p, st) do
    id = Map.get(p, :id) || Identificadores.generar("MC", map_size(st))
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    {:ok, m} = Mascota.construir(Map.merge(p, %{id: id, fecha_registro: fecha}))
    nuevo_st = Map.put(st, id, m)
    AlmacenArchivo.guardar(:mascotas, Map.values(nuevo_st))
    {:reply, {:ok, m}, nuevo_st}
  end

  defp ejecutar_confirmacion(id_p, id_e, u, fecha, st) do
    with {:ok, p} <- Map.fetch(st, id_p),
         {:ok, e} <- Map.fetch(st, id_e),
         true <- p.estado != :resuelta and e.estado != :resuelta or {:error, :ya_cerrada},
         {:ok, p_res} <- Estados.transitar(p, :resuelta, u, fecha),
         {:ok, e_res} <- Estados.transitar(e, :resuelta, u, fecha) do
      nuevo_st = st |> Map.put(id_p, p_res) |> Map.put(id_e, e_res)
      AlmacenArchivo.guardar(:mascotas, Map.values(nuevo_st))
      {:reply, {:ok, {p_res, e_res}}, nuevo_st}
    else
      :error -> {:reply, {:error, :mascota_no_encontrada}, st}
      error -> {:reply, error, st}
    end
  end

  defp ejecutar_actualizacion(id, est, u, fecha, st) do
    case Map.get(st, id) do
      nil -> {:reply, {:error, :mascota_no_encontrada}, st}
      m ->
        case Estados.transitar(m, est, u, fecha) do
          {:ok, m_act} ->
            nuevo_st = Map.put(st, id, m_act)
            AlmacenArchivo.guardar(:mascotas, Map.values(nuevo_st))
            {:reply, {:ok, m_act}, nuevo_st}
          error -> {:reply, error, st}
        end
    end
  end
end
