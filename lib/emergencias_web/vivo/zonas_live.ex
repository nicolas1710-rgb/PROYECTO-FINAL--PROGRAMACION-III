defmodule EmergenciasWeb.Vivo.ZonasLive do
  @moduledoc "LiveView de division territorial jerarquica y consulta de estado de zonas."
  use EmergenciasWeb, :live_view
  alias Emergencias.Aplicacion.CasosUso.GestionarZonas
  alias Emergencias.Infraestructura.MensajesError
  alias EmergenciasWeb.Componentes.Navegacion
  alias EmergenciasWeb.Notificador

  @impl true
  def mount(_p, _s, socket) do
    if connected?(socket), do: Notificador.suscribir()
    {:ok, socket |> assign(zona_id: nil, estado_zona: nil) |> cargar_datos()}
  end

  @impl true
  def handle_event("registrar_zona", %{"codigo" => c, "nombre" => n, "nivel" => g, "personas" => p}, s),
    do: dar_respuesta(s, GestionarZonas.registrar_zona(c, n, g, p, s.assigns.usuario), "Zona registrada.")
  def handle_event("registrar_sector", %{"zona_id" => z, "codigo" => sec, "nombre" => n, "personas" => p}, s),
    do: dar_respuesta(s, GestionarZonas.registrar_sector(z, sec, n, p, s.assigns.usuario), "Sector registrado.")
  def handle_event("registrar_punto", %{"zona_id" => z, "sector_id" => sec, "codigo" => pt, "nombre" => n}, s),
    do: dar_respuesta(s, GestionarZonas.registrar_punto(z, sec, pt, n, 0, s.assigns.usuario), "Punto registrado.")
  def handle_event("seleccionar_zona", %{"zona_id" => z}, s),
    do: {:noreply, s |> assign(zona_id: z) |> cargar_estado_zona(z)}

  @impl true
  def handle_info({:cambio, _tema}, socket), do: {:noreply, cargar_datos(socket)}

  defp dar_respuesta(socket, resultado, mensaje_ok) do
    case resultado do
      {:ok, _} ->
        Notificador.difundir_cambio(:zonas)
        {:noreply, socket |> put_flash(:info, mensaje_ok) |> cargar_datos()}
      {:error, r} -> {:noreply, put_flash(socket, :error, MensajesError.obtener_mensaje(r))}
    end
  end

  defp cargar_datos(socket) do
    {:ok, zonas} = GestionarZonas.listar_zonas(socket.assigns.usuario)
    z_id = socket.assigns.zona_id || (if zonas != [], do: hd(zonas).id, else: nil)
    socket |> assign(zonas: zonas, zona_id: z_id) |> cargar_estado_zona(z_id)
  end

  defp cargar_estado_zona(socket, nil), do: assign(socket, estado_zona: nil)
  defp cargar_estado_zona(socket, z_id) do
    case GestionarZonas.consultar_estado_zona(z_id, socket.assigns.usuario) do
      {:ok, st} -> assign(socket, estado_zona: st)
      _ -> assign(socket, estado_zona: nil)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Navegacion.barra_superior usuario={@usuario} flash={@flash} pagina_activa="zonas" />
    <main class="max-w-7xl mx-auto px-4 py-2 space-y-3 text-xs">
      <div class="bg-white p-2 rounded shadow border"><h1 class="text-base font-bold text-slate-800">Organización Territorial Jerárquica</h1></div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-2">
        <form phx-submit="registrar_zona" class="bg-white p-2 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">1. Registrar Zona</div>
          <input type="text" name="codigo" placeholder="Código (Z001)" required class="w-full border p-1 rounded" /><input type="text" name="nombre" placeholder="Nombre" required class="w-full border p-1 rounded" />
          <select name="nivel" class="w-full border p-1 rounded bg-white"><option value="critico">Crítico</option><option value="alto">Alto</option><option value="medio">Medio</option><option value="bajo">Bajo</option></select>
          <input type="number" name="personas" placeholder="Personas" value="0" min="0" class="w-full border p-1 rounded" /><button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Guardar Zona</button>
        </form>
        <form phx-submit="registrar_sector" class="bg-white p-2 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">2. Registrar Sector</div>
          <input type="text" name="zona_id" placeholder="ID Zona Padre (Z001)" required class="w-full border p-1 rounded" /><input type="text" name="codigo" placeholder="Código Sector (S001)" required class="w-full border p-1 rounded" /><input type="text" name="nombre" placeholder="Nombre Sector" required class="w-full border p-1 rounded" /><input type="number" name="personas" placeholder="Personas" value="0" min="0" class="w-full border p-1 rounded" /><button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Guardar Sector</button>
        </form>
        <form phx-submit="registrar_punto" class="bg-white p-2 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">3. Registrar Punto</div>
          <input type="text" name="zona_id" placeholder="ID Zona (Z001)" required class="w-full border p-1 rounded" /><input type="text" name="sector_id" placeholder="ID Sector (S001)" required class="w-full border p-1 rounded" /><input type="text" name="codigo" placeholder="Código Punto (PT01)" required class="w-full border p-1 rounded" /><input type="text" name="nombre" placeholder="Nombre Punto" required class="w-full border p-1 rounded" /><button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Guardar Punto</button>
        </form>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-2">
        <div class="bg-white p-2 rounded shadow border overflow-x-auto max-h-56">
          <div class="font-bold text-slate-700 mb-1">Zonas Registradas</div>
          <table class="min-w-full divide-y divide-slate-200">
            <thead><tr><th>Código</th><th>Nombre</th><th>Gravedad</th><th>Acción</th></tr></thead>
            <tbody><%= for z <- @zonas do %><tr class={["hover:bg-slate-50", if(@zona_id == z.id, do: "bg-amber-50 font-bold")]}>
              <td class="font-mono py-1">{z.id}</td><td>{z.nombre}</td><td class="capitalize">{z.nivel_gravedad}</td>
              <td><button phx-click="seleccionar_zona" phx-value-zona_id={z.id} class="text-blue-600 hover:underline">Ver Estado</button></td>
            </tr><% end %></tbody>
          </table>
        </div>
        <div class="bg-white p-2 rounded shadow border">
          <div class="font-bold text-slate-700 mb-1">Censo Consolidado (Recursión Pura)</div>
          <%= if @estado_zona do %>
            <div class="p-1 bg-slate-50 rounded border mb-2"><span class="font-bold">Zona: {@estado_zona.zona.nombre} ({@estado_zona.zona.id})</span></div>
            <div class="grid grid-cols-3 gap-2 text-center font-bold">
              <div class="bg-blue-50 p-1.5 rounded text-blue-700"><div>{@estado_zona.total_sectores}</div><div class="text-2xs text-slate-500 font-normal">Sectores</div></div>
              <div class="bg-purple-50 p-1.5 rounded text-purple-700"><div>{@estado_zona.total_puntos}</div><div class="text-2xs text-slate-500 font-normal">Puntos</div></div>
              <div class="bg-red-50 p-1.5 rounded text-red-700"><div>{@estado_zona.total_personas}</div><div class="text-2xs text-slate-500 font-normal">Damnificados</div></div>
            </div>
          <% else %><div class="text-slate-400 py-6 text-center">Selecciona una zona para consultar su censo.</div><% end %>
        </div>
      </div>
    </main>
    """
  end
end
