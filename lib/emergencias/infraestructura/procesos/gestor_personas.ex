defmodule Emergencias.Infraestructura.Procesos.GestorPersonas do
  @moduledoc "GenServer para el censo de personas afectadas y mensajeria familiar."
  use GenServer
  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoPersonas

  alias Emergencias.Dominio.Modelos.{Mensaje, Persona}
  alias Emergencias.Dominio.Reglas.{Estados, Identificadores}
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  def iniciar(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def start_link(opts \\ []), do: iniciar(opts)
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :iniciar, [opts]}, type: :worker}

  @impl true
  def reportar(p), do: GenServer.call(__MODULE__, {:reportar, p})
  @impl true
  def buscar(criterio), do: GenServer.call(__MODULE__, {:buscar, criterio})
  @impl true
  def actualizar_estado(doc, est, u, fecha, alb), do: GenServer.call(__MODULE__, {:actualizar_estado, doc, est, u, fecha, alb})
  @impl true
  def listar, do: GenServer.call(__MODULE__, :listar)
  @impl true
  def enviar_mensaje(p), do: GenServer.call(__MODULE__, {:enviar_mensaje, p})
  @impl true
  def listar_mensajes(doc), do: GenServer.call(__MODULE__, {:listar_mensajes, doc})
  @impl true
  def listar_todos_mensajes, do: GenServer.call(__MODULE__, :listar_todos_mensajes)

  @impl true
  def init(_opts) do
    pers = AlmacenArchivo.cargar(:personas) |> Map.new(fn p -> {p.documento, p} end)
    mens = AlmacenArchivo.cargar(:mensajes)
    {:ok, %{personas: pers, mensajes: mens}}
  end

  @impl true
  def handle_call({:reportar, p}, _from, st), do: ejecutar_reporte(p, st)
  @impl true
  def handle_call({:buscar, crit}, _from, st), do: ejecutar_busqueda(crit, st)
  @impl true
  def handle_call({:actualizar_estado, doc, est, u, fecha, alb}, _from, st), do: ejecutar_actualizacion(doc, est, u, fecha, alb, st)
  @impl true
  def handle_call(:listar, _from, st), do: {:reply, Map.values(st.personas), st}
  @impl true
  def handle_call({:enviar_mensaje, p}, _from, st), do: ejecutar_envio_mensaje(p, st)
  @impl true
  def handle_call({:listar_mensajes, doc}, _from, st) do
    mens = Enum.filter(st.mensajes, fn m -> m.documento_persona == doc end)
    {:reply, mens, st}
  end
  @impl true
  def handle_call(:listar_todos_mensajes, _from, st), do: {:reply, st.mensajes, st}

  defp ejecutar_reporte(p, st) do
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    {:ok, persona} = Persona.construir(Map.merge(p, %{fecha_registro: fecha}))
    nuevo_st = %{st | personas: Map.put(st.personas, persona.documento, persona)}
    AlmacenArchivo.guardar(:personas, Map.values(nuevo_st.personas))
    {:reply, {:ok, persona}, nuevo_st}
  end

  defp ejecutar_busqueda(criterio, st) when is_binary(criterio) do
    case Map.get(st.personas, criterio) do
      nil ->
        encontrados = Enum.filter(Map.values(st.personas), fn p -> String.contains?(String.downcase(p.nombre), String.downcase(criterio)) end)
        if encontrados != [], do: {:reply, {:ok, hd(encontrados)}, st}, else: {:reply, {:error, :persona_no_encontrada}, st}
      p -> {:reply, {:ok, p}, st}
    end
  end
  defp ejecutar_busqueda(crit_map, st) when is_map(crit_map) do
    filtrados = Enum.filter(Map.values(st.personas), fn p ->
      Enum.all?(crit_map, fn {k, v} ->
        case k do
          :nombre -> String.contains?(String.downcase(p.nombre), String.downcase(v))
          :zona -> String.downcase(to_string(p.zona)) == String.downcase(to_string(v))
          :estado -> to_string(p.estado) == to_string(v)
          _ -> true
        end
      end)
    end)
    {:reply, {:ok, filtrados}, st}
  end

  defp ejecutar_actualizacion(doc, est, u, fecha, alb, st) do
    case Map.get(st.personas, doc) do
      nil -> {:reply, {:error, :persona_no_encontrada}, st}
      p ->
        case Estados.transitar(p, est, u, fecha) do
          {:ok, p_act} ->
            p_final = if alb, do: %{p_act | codigo_albergue: alb}, else: p_act
            nuevo_st = %{st | personas: Map.put(st.personas, doc, p_final)}
            AlmacenArchivo.guardar(:personas, Map.values(nuevo_st.personas))
            {:reply, {:ok, p_final}, nuevo_st}
          error -> {:reply, error, st}
        end
    end
  end

  defp ejecutar_envio_mensaje(p, st) do
    id = Identificadores.generar("M", length(st.mensajes))
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    {:ok, m} = Mensaje.construir(Map.merge(p, %{id: id, fecha: fecha}))
    nuevo_st = %{st | mensajes: [m | st.mensajes]}
    AlmacenArchivo.guardar(:mensajes, nuevo_st.mensajes)
    {:reply, {:ok, m}, nuevo_st}
  end
end
