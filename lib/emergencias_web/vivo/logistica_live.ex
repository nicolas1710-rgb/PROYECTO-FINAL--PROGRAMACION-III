defmodule EmergenciasWeb.Vivo.LogisticaLive do
  @moduledoc "LiveView de logistica humanitaria, asignacion atomica y simulacion concurrente."
  use EmergenciasWeb, :live_view
  alias Emergencias.Aplicacion.CasosUso.GestionarLogistica
  alias Emergencias.Infraestructura.MensajesError
  alias EmergenciasWeb.Componentes.Navegacion
  alias EmergenciasWeb.Notificador

  @impl true
  def mount(_p, _s, socket) do
    if connected?(socket), do: Notificador.suscribir()
    {:ok, socket |> assign(filtros: %{}, conflicto: nil) |> cargar_datos()}
  end

  @impl true
  def handle_event("registrar_recurso", %{"codigo" => c, "nombre" => n, "cantidad" => k, "unidad" => u, "ubicacion" => ub} = p, s),
    do: dar_respuesta(s, GestionarLogistica.registrar_recurso(c, n, k, u, ub, p["categoria"], s.assigns.usuario), "Recurso registrado.")
  def handle_event("registrar_necesidad", %{"zona" => z, "recurso" => r, "cantidad" => k, "prioridad" => p} = pm, s),
    do: dar_respuesta(s, GestionarLogistica.registrar_necesidad(z, r, k, p, pm["descripcion"], s.assigns.usuario), "Necesidad registrada.")
  def handle_event("asignar_recurso", %{"recurso_id" => r, "necesidad_id" => n, "cantidad" => k}, s),
    do: dar_respuesta(s, GestionarLogistica.asignar_recurso(r, n, k, s.assigns.usuario), "Asignación completada.")
  def handle_event("filtrar", %{"zona" => z, "prioridad" => p}, socket) do
    {:noreply, socket |> assign(filtros: %{zona: if(z != "", do: z), prioridad: if(p != "", do: p)}) |> cargar_datos()}
  end
  def handle_event("simular_conflicto", _p, socket), do: {:noreply, simular_conflicto(socket)}

  @impl true
  def handle_info({:cambio, _t}, socket), do: {:noreply, cargar_datos(socket)}

  def simular_conflicto(socket) do
    u = socket.assigns.usuario
    r_id = "RCONF_#{:erlang.unique_integer([:positive])}"
    {:ok, _} = GestionarLogistica.registrar_recurso(r_id, "agua", 50, "litros", "Z001", "hidratacion", u)
    {:ok, n1} = GestionarLogistica.registrar_necesidad("Z001", "agua", 30, "alta", "Demostracion 1", u)
    {:ok, n2} = GestionarLogistica.registrar_necesidad("Z001", "agua", 25, "alta", "Demostracion 2", u)
    res = Task.async_stream([{n1.id, 30}, {n2.id, 25}], fn {n, k} -> {n, k, GestionarLogistica.asignar_recurso(r_id, n, k, u)} end, max_concurrency: 2)
          |> Enum.map(fn {:ok, item} -> item end)
    {:ok, recs} = GestionarLogistica.listar_recursos([], u)
    disp = Enum.find(recs, &(&1.id == r_id)) |> Map.get(:cantidad_disponible, 0)
    Notificador.difundir_cambio(:logistica)
    socket |> assign(conflicto: %{solicitudes: res, stock_final: disp}) |> cargar_datos()
  end

  defp dar_respuesta(socket, resultado, mensaje_ok) do
    case resultado do
      {:ok, _} ->
        Notificador.difundir_cambio(:logistica)
        {:noreply, socket |> put_flash(:info, mensaje_ok) |> cargar_datos()}
      {:error, r} -> {:noreply, put_flash(socket, :error, MensajesError.obtener_mensaje(r))}
    end
  end

  defp cargar_datos(socket) do
    u = socket.assigns.usuario
    {:ok, recs} = GestionarLogistica.listar_recursos([], u)
    {:ok, necs} = GestionarLogistica.listar_necesidades(socket.assigns.filtros, u)
    peso = fn p -> %{:critica => 1, "critica" => 1, :alta => 2, "alta" => 2, :media => 3, "media" => 3, :baja => 4, "baja" => 4}[p] || 5 end
    assign(socket, recursos: recs, necesidades: Enum.sort_by(necs, &peso.(&1.prioridad)))
  end

  defp formatear_resultado({:ok, _}), do: "CONFIRMADA (Asignada)"
  defp formatear_resultado({:error, r}), do: "RECHAZADA (#{MensajesError.obtener_mensaje(r)})"

  @impl true
  def render(assigns) do
    ~H"""
    <Navegacion.barra_superior usuario={@usuario} flash={@flash} pagina_activa="logistica" />
    <main class="max-w-7xl mx-auto px-4 py-2 space-y-3 text-xs">
      <div class="flex justify-between items-center bg-white p-2.5 rounded shadow border">
        <h1 class="text-base font-bold text-slate-800">Centro Logístico Humanitario</h1>
        <button phx-click="simular_conflicto" class="bg-amber-600 hover:bg-amber-700 text-white font-bold px-3 py-1.5 rounded shadow">Simular Conflicto 30 L vs 25 L</button>
      </div>
      <%= if @conflicto do %>
        <div class="bg-amber-50 border border-amber-300 p-2.5 rounded">
          <div class="font-bold text-amber-900">Simulación 2 Asignaciones Simultáneas sobre 50 L iniciales:</div>
          <%= for {nid, cant, res} <- @conflicto.solicitudes do %>
            <div><span class="font-mono font-bold">{nid}</span> ({cant} L): {formatear_resultado(res)}</div>
          <% end %>
          <div class="font-bold text-slate-800 mt-0.5">Stock final resultante: <span class="text-blue-700">{@conflicto.stock_final} L</span> (Esperado: 20 L)</div>
        </div>
      <% end %>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-2.5">
        <form phx-submit="registrar_recurso" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Registrar Recurso</div>
          <input type="text" name="codigo" placeholder="Código (R001)" required class="w-full border p-1 rounded" /><input type="text" name="nombre" placeholder="Nombre (agua)" required class="w-full border p-1 rounded" /><input type="number" name="cantidad" placeholder="Cantidad" required min="1" class="w-full border p-1 rounded" /><input type="text" name="unidad" placeholder="Unidad" required class="w-full border p-1 rounded" /><input type="text" name="ubicacion" placeholder="Ubicación" required class="w-full border p-1 rounded" />
          <button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Guardar Recurso</button>
        </form>
        <form phx-submit="registrar_necesidad" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Reportar Necesidad</div>
          <input type="text" name="zona" placeholder="Zona (Z001)" required class="w-full border p-1 rounded" /><input type="text" name="recurso" placeholder="Tipo (agua)" required class="w-full border p-1 rounded" /><input type="number" name="cantidad" placeholder="Cantidad" required min="1" class="w-full border p-1 rounded" /><select name="prioridad" class="w-full border p-1 rounded bg-white"><option value="critica">Crítica</option><option value="alta" selected>Alta</option><option value="media">Media</option><option value="baja">Baja</option></select>
          <button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Reportar Necesidad</button>
        </form>
        <form phx-submit="asignar_recurso" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Asignar Suministro</div>
          <input type="text" name="recurso_id" placeholder="ID Recurso (R001)" required class="w-full border p-1 rounded" /><input type="text" name="necesidad_id" placeholder="ID Necesidad (N001)" required class="w-full border p-1 rounded" /><input type="number" name="cantidad" placeholder="Cantidad a asignar" required min="1" class="w-full border p-1 rounded" />
          <button type="submit" class="w-full bg-emerald-700 text-white py-1 rounded font-bold">Despachar Atómicamente</button>
        </form>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-2.5">
        <div class="bg-white p-2.5 rounded shadow border overflow-x-auto max-h-56">
          <div class="font-bold text-slate-700 mb-1">Inventario de Suministros</div>
          <table class="min-w-full divide-y divide-slate-200">
            <thead><tr><th>ID</th><th>Nombre</th><th>Disp</th><th>Total</th><th>Ubic</th></tr></thead>
            <tbody><%= for r <- @recursos do %><tr class="hover:bg-slate-50"><td class="font-mono">{r.id}</td><td>{r.nombre}</td><td class="font-bold text-blue-600">{r.cantidad_disponible}</td><td>{r.cantidad_total}</td><td>{r.ubicacion}</td></tr><% end %></tbody>
          </table>
        </div>
        <div class="bg-white p-2.5 rounded shadow border overflow-x-auto max-h-56">
          <div class="flex justify-between items-center mb-1">
            <div class="font-bold text-slate-700">Necesidades (Prioridad)</div>
            <form id="form-filtro-necesidades" phx-change="filtrar" class="flex gap-1">
              <input type="text" name="zona" value={@filtros[:zona]} placeholder="Zona" class="border p-0.5 rounded w-16" />
              <select name="prioridad" class="border p-0.5 rounded bg-white"><option value="">Todas</option><option value="critica">Crítica</option><option value="alta">Alta</option><option value="media">Media</option><option value="baja">Baja</option></select>
            </form>
          </div>
          <table class="min-w-full divide-y divide-slate-200">
            <thead><tr><th>ID</th><th>Zona</th><th>Recurso</th><th>Sol/Asig</th><th>Prio</th><th>Estado</th></tr></thead>
            <tbody><%= for n <- @necesidades do %><tr class="hover:bg-slate-50"><td class="font-mono">{n.id}</td><td>{n.codigo_zona}</td><td>{n.tipo_recurso}</td><td>{n.cantidad_solicitada}/{n.cantidad_asignada}</td><td class="capitalize font-semibold">{n.prioridad}</td><td>{n.estado}</td></tr><% end %></tbody>
          </table>
        </div>
      </div>
    </main>
    """
  end
end
