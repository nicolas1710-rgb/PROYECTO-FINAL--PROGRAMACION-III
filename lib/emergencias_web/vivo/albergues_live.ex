defmodule EmergenciasWeb.Vivo.AlberguesLive do
  @moduledoc "LiveView de coordinacion y control de aforo en albergues temporales."
  use EmergenciasWeb, :live_view
  alias Emergencias.Aplicacion.CasosUso.GestionarAlbergues
  alias Emergencias.Infraestructura.MensajesError
  alias EmergenciasWeb.Componentes.Navegacion
  alias EmergenciasWeb.Notificador

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Notificador.suscribir()
    {:ok, cargar_datos(socket)}
  end

  @impl true
  def handle_event("registrar_albergue", %{"nombre" => n, "zona" => z, "capacidad" => c}, s),
    do: dar_respuesta(s, GestionarAlbergues.registrar_albergue(n, z, c, s.assigns.usuario), "Albergue registrado.")
  def handle_event("registrar_entrada", %{"albergue_id" => id, "doc" => d}, s),
    do: dar_respuesta(s, GestionarAlbergues.registrar_entrada(id, d, s.assigns.usuario), "Ingreso registrado.")
  def handle_event("registrar_salida", %{"albergue_id" => id, "doc" => d}, s),
    do: dar_respuesta(s, GestionarAlbergues.registrar_salida(id, d, s.assigns.usuario), "Salida registrada.")

  @impl true
  def handle_info({:cambio, _tema}, socket), do: {:noreply, cargar_datos(socket)}

  defp dar_respuesta(socket, resultado, mensaje_ok) do
    case resultado do
      {:ok, _} ->
        Notificador.difundir_cambio(:albergues)
        {:noreply, socket |> put_flash(:info, mensaje_ok) |> cargar_datos()}
      {:error, r} -> {:noreply, put_flash(socket, :error, MensajesError.obtener_mensaje(r))}
    end
  end

  defp cargar_datos(socket) do
    case GestionarAlbergues.generar_reporte_albergues(socket.assigns.usuario) do
      {:ok, albs} -> assign(socket, albergues: albs)
      _ -> assign(socket, albergues: [])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Navegacion.barra_superior usuario={@usuario} flash={@flash} pagina_activa="albergues" />
    <main class="max-w-7xl mx-auto px-4 py-2 space-y-3 text-xs">
      <div class="bg-white p-2.5 rounded shadow border"><h1 class="text-base font-bold text-slate-800">Control de Aforo y Gestión de Albergues</h1></div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-2.5">
        <form phx-submit="registrar_albergue" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Registrar Albergue</div>
          <input type="text" name="nombre" placeholder="Nombre (Estadio)" required class="w-full border p-1 rounded" /><input type="text" name="zona" placeholder="Zona (Z001)" required class="w-full border p-1 rounded" /><input type="number" name="capacidad" placeholder="Capacidad máxima" required min="1" class="w-full border p-1 rounded" />
          <button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Guardar Albergue</button>
        </form>
        <form phx-submit="registrar_entrada" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Ingreso de Damnificado</div>
          <input type="text" name="albergue_id" placeholder="ID Albergue (ALB001)" required class="w-full border p-1 rounded" /><input type="text" name="doc" placeholder="Documento damnificado" required class="w-full border p-1 rounded" />
          <button type="submit" class="w-full bg-emerald-700 text-white py-1 rounded font-bold">Registrar Entrada</button>
        </form>
        <form phx-submit="registrar_salida" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Egreso de Damnificado</div>
          <input type="text" name="albergue_id" placeholder="ID Albergue (ALB001)" required class="w-full border p-1 rounded" /><input type="text" name="doc" placeholder="Documento damnificado" required class="w-full border p-1 rounded" />
          <button type="submit" class="w-full bg-amber-700 text-white py-1 rounded font-bold">Registrar Salida</button>
        </form>
      </div>
      <div class="bg-white p-2.5 rounded shadow border overflow-x-auto">
        <div class="font-bold text-slate-700 mb-1">Reporte de Albergues (Ordenados por Ocupación - Merge Sort)</div>
        <table class="min-w-full divide-y divide-slate-200">
          <thead><tr><th>ID</th><th>Nombre</th><th>Zona</th><th>Alojados</th><th>Capacidad</th><th>Ocupación (%)</th></tr></thead>
          <tbody><%= for a <- @albergues do %>
            <% oc = MapSet.size(a.personas_alojadas) %>
            <% pct = Float.round(oc * 100.0 / max(a.capacidad_maxima, 1), 1) %>
            <tr class="hover:bg-slate-50">
              <td class="font-mono py-1">{a.id}</td><td>{a.nombre}</td><td>{a.codigo_zona}</td>
              <td class="font-bold text-blue-700">{oc}</td><td>{a.capacidad_maxima}</td>
              <td><div class="flex items-center gap-2"><div class="w-20 bg-slate-200 rounded-full h-1.5"><div class="bg-indigo-600 h-1.5 rounded-full" style={"width: #{min(pct, 100.0)}%"}></div></div><span class="font-bold">{pct}%</span></div></td>
            </tr>
          <% end %></tbody>
        </table>
      </div>
    </main>
    """
  end
end
