defmodule EmergenciasWeb.Vivo.ResumenLive do
  @moduledoc "LiveView de resumen ejecutivo global y monitoreo de recursos criticos."
  use EmergenciasWeb, :live_view
  alias Emergencias.Aplicacion.CasosUso.GenerarResumenes
  alias Emergencias.Infraestructura.MensajesError
  alias EmergenciasWeb.Componentes.Navegacion
  alias EmergenciasWeb.Notificador

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Notificador.suscribir()
    {:ok, socket |> assign(umbral: 10) |> cargar_datos()}
  end

  @impl true
  def handle_event("filtrar_umbral", %{"umbral" => u}, socket) do
    case Integer.parse(u) do
      {num, ""} when num >= 0 -> {:noreply, socket |> assign(umbral: num) |> cargar_datos()}
      _ -> {:noreply, put_flash(socket, :error, MensajesError.obtener_mensaje(:numero_invalido))}
    end
  end

  @impl true
  def handle_info({:cambio, _tema}, socket), do: {:noreply, cargar_datos(socket)}

  defp cargar_datos(socket) do
    u = socket.assigns.usuario
    case GenerarResumenes.generar_resumen_ejecutivo(u) do
      {:ok, sum} ->
        {:ok, crit} = GenerarResumenes.listar_recursos_criticos(socket.assigns.umbral, u)
        assign(socket, resumen: sum, criticos: crit.recursos_criticos, movilizados: crit.total_unidades_movilizadas)
      {:error, r} -> put_flash(socket, :error, MensajesError.obtener_mensaje(r))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Navegacion.barra_superior usuario={@usuario} flash={@flash} pagina_activa="resumen" />
    <main class="max-w-7xl mx-auto px-4 py-2 space-y-3">
      <h1 class="text-lg font-bold text-slate-800">Consolidado General de la Emergencia</h1>
      <%= if assigns[:resumen] do %>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-2.5">
          <%= for {tit, val, col} <- [{"Recursos Disp", @resumen.total_recursos_disponibles, "border-emerald-500"}, {"Necesidades Pend", @resumen.necesidades_pendientes, "border-amber-500"}, {"Damnificados", @resumen.personas_afectadas_total, "border-red-500"}, {"Censados", @resumen.personas_censadas, "border-blue-500"}, {"Albergados", @resumen.personas_en_albergue, "border-purple-500"}, {"Mensajes", @resumen.mensajes_enviados, "border-indigo-500"}, {"Mascotas Activas", @resumen.mascotas_activas, "border-orange-500"}, {"Mascotas Resueltas", @resumen.mascotas_resueltas, "border-teal-500"}] do %>
            <div class={["bg-white p-2.5 rounded shadow border-l-4", col]}>
              <div class="text-2xs font-bold text-slate-500 uppercase">{tit}</div>
              <div class="text-lg font-black text-slate-900">{val}</div>
            </div>
          <% end %>
        </div>
        <div class="bg-white p-3 rounded shadow border">
          <div class="flex justify-between items-center mb-1.5">
            <h2 class="text-xs font-bold text-slate-800">Suministros Críticos (Movilizados: {@movilizados})</h2>
            <form id="form-umbral-resumen" phx-change="filtrar_umbral" class="flex items-center gap-1 text-xs">
              <label>Umbral:</label><input type="number" name="umbral" value={@umbral} min="0" class="w-16 p-1 border rounded text-center" />
            </form>
          </div>
          <table class="min-w-full divide-y divide-slate-200 text-xs">
            <thead class="bg-slate-50 text-slate-700"><tr><th class="py-1 text-left">Código</th><th class="py-1 text-left">Nombre</th><th class="py-1 text-left">Disponible</th><th class="py-1 text-left">Ubicación</th></tr></thead>
            <tbody>
              <%= for r <- @criticos do %><tr class="hover:bg-slate-50"><td class="py-1 font-mono">{r.id}</td><td class="capitalize">{r.nombre}</td><td class="font-bold text-red-600">{r.cantidad_disponible}</td><td>{r.ubicacion}</td></tr><% end %>
              <%= if @criticos == [] do %><tr><td colspan="4" class="py-2 text-center text-slate-400">Sin recursos por debajo del umbral.</td></tr><% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </main>
    """
  end
end
