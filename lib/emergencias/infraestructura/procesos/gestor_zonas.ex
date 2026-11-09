defmodule Emergencias.Infraestructura.Procesos.GestorZonas do
  @moduledoc "GenServer para la gestion concurrente de zonas, sectores y puntos."
  use GenServer
  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoZonas

  alias Emergencias.Dominio.Modelos.{PuntoAtencion, Sector, Zona}
  alias Emergencias.Dominio.Reglas.JerarquiaZona
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  def iniciar(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def start_link(opts \\ []), do: iniciar(opts)
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :iniciar, [opts]}, type: :worker}

  @impl true
  def registrar_zona(params), do: GenServer.call(__MODULE__, {:registrar_zona, params})
  @impl true
  def registrar_sector(z_id, params), do: GenServer.call(__MODULE__, {:registrar_sector, z_id, params})
  @impl true
  def registrar_punto(z_id, s_id, params), do: GenServer.call(__MODULE__, {:registrar_punto, z_id, s_id, params})
  @impl true
  def consultar(id), do: GenServer.call(__MODULE__, {:consultar, id})
  @impl true
  def listar, do: GenServer.call(__MODULE__, :listar)

  @impl true
  def init(_opts) do
    lista = AlmacenArchivo.cargar(:zonas)
    {:ok, Map.new(lista, fn z -> {z.id, z} end)}
  end

  @impl true
  def handle_call({:registrar_zona, p}, _from, st), do: ejecutar_registro_zona(p, st)
  @impl true
  def handle_call({:registrar_sector, z_id, p}, _from, st), do: ejecutar_registro_sector(z_id, p, st)
  @impl true
  def handle_call({:registrar_punto, z_id, s_id, p}, _from, st), do: ejecutar_registro_punto(z_id, s_id, p, st)
  @impl true
  def handle_call({:consultar, id}, _from, st) do
    case Map.get(st, id) do
      nil -> {:reply, {:error, :zona_no_encontrada}, st}
      zona -> {:reply, {:ok, zona}, st}
    end
  end
  @impl true
  def handle_call(:listar, _from, st), do: {:reply, Map.values(st), st}

  defp ejecutar_registro_zona(p, st) do
    id = Map.get(p, :id) || Map.get(p, :codigo)
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    {:ok, z} = Zona.construir(%{id: id, nombre: p.nombre, nivel_gravedad: p.nivel_gravedad, personas_afectadas: Map.get(p, :personas_afectadas, 0), fecha_registro: fecha})
    nuevo_st = Map.put(st, id, z)
    AlmacenArchivo.guardar(:zonas, Map.values(nuevo_st))
    {:reply, {:ok, z}, nuevo_st}
  end

  defp ejecutar_registro_sector(z_id, p, st) do
    case Map.get(st, z_id) do
      nil -> {:reply, {:error, :zona_no_encontrada}, st}
      %Zona{sectores: secs} = z ->
        sec = %Sector{id: p.id, nombre: p.nombre, personas_afectadas: Map.get(p, :personas_afectadas, 0), puntos_atencion: []}
        z_act = %{z | sectores: secs ++ [sec]}
        nuevo_st = Map.put(st, z_id, z_act)
        AlmacenArchivo.guardar(:zonas, Map.values(nuevo_st))
        {:reply, {:ok, sec}, nuevo_st}
    end
  end

  defp ejecutar_registro_punto(z_id, s_id, p, st) do
    case Map.get(st, z_id) do
      nil -> {:reply, {:error, :zona_no_encontrada}, st}
      %Zona{sectores: secs} = z ->
        pto = %PuntoAtencion{id: p.id, nombre: p.nombre, personas_afectadas: Map.get(p, :personas_afectadas, 0)}
        case JerarquiaZona.agregar_punto_a_sectores(secs, s_id, pto) do
          {:ok, nuevos_secs} ->
            z_act = %{z | sectores: nuevos_secs}
            nuevo_st = Map.put(st, z_id, z_act)
            AlmacenArchivo.guardar(:zonas, Map.values(nuevo_st))
            {:reply, {:ok, pto}, nuevo_st}
          error -> {:reply, error, st}
        end
    end
  end
end
