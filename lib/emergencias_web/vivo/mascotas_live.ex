defmodule EmergenciasWeb.Vivo.MascotasLive do
  @moduledoc "LiveView de reporte, emparejamiento inteligente y resolucion de mascotas extraviadas."
  use EmergenciasWeb, :live_view
  alias Emergencias.Aplicacion.CasosUso.GestionarMascotas
  alias Emergencias.Infraestructura.MensajesError
  alias EmergenciasWeb.Componentes.Navegacion
  alias EmergenciasWeb.Notificador

  @impl true
  def mount(_p, _s, socket) do
    if connected?(socket), do: Notificador.suscribir()
    {:ok, socket |> assign(filtros: %{}, coincidencias: nil) |> cargar_datos()}
  end

  @impl true
  def handle_event("reportar_mascota", %{"tipo" => t, "especie" => e, "color" => c, "tamano" => tam, "zona" => z} = p, s),
    do: dar_respuesta(s, GestionarMascotas.reportar_mascota(t, e, c, tam, z, p["nombre"] || "", [], s.assigns.usuario), "Mascota reportada.")
  def handle_event("filtrar", %{"especie" => e, "zona" => z, "estado" => est}, s),
    do: {:noreply, s |> assign(filtros: %{especie: if(e != "", do: e), zona: if(z != "", do: z), estado: if(est != "", do: est)}) |> cargar_datos()}
  def handle_event("buscar_coincidencias", _params, socket) do
    case GestionarMascotas.emparejar_mascotas(60, socket.assigns.usuario) do
      {:ok, pares} -> {:noreply, assign(socket, coincidencias: pares)}
      {:error, r} -> {:noreply, put_flash(socket, :error, MensajesError.obtener_mensaje(r))}
    end
  end
  def handle_event("confirmar_coincidencia", %{"perdida" => p, "encontrada" => e}, s),
    do: dar_respuesta(s, GestionarMascotas.confirmar_coincidencia(p, e, s.assigns.usuario), "Coincidencia confirmada y resuelta.")
  def handle_event("actualizar_estado", %{"mascota_id" => id, "estado" => est}, s),
    do: dar_respuesta(s, GestionarMascotas.actualizar_estado_mascota(id, est, s.assigns.usuario), "Estado de mascota actualizado.")

  @impl true
  def handle_info({:cambio, _tema}, socket), do: {:noreply, cargar_datos(socket)}

  defp dar_respuesta(socket, resultado, mensaje_ok) do
    case resultado do
      {:ok, _} ->
        Notificador.difundir_cambio(:mascotas)
        {:noreply, socket |> put_flash(:info, mensaje_ok) |> assign(coincidencias: nil) |> cargar_datos()}
      {:error, r} -> {:noreply, put_flash(socket, :error, MensajesError.obtener_mensaje(r))}
    end
  end

  defp cargar_datos(socket) do
    {:ok, ms} = GestionarMascotas.listar_mascotas(socket.assigns.filtros, socket.assigns.usuario)
    assign(socket, mascotas: ms)
  end

  defp puede_modificar?(m, u), do: u.rol in [:coordinador, :administrador] or m.usuario == u.nombre

  @impl true
  def render(assigns) do
    ~H"""
    <Navegacion.barra_superior usuario={@usuario} flash={@flash} pagina_activa="mascotas" />
    <main class="max-w-7xl mx-auto px-4 py-2 space-y-3 text-xs">
      <div class="bg-white p-2.5 rounded shadow border flex justify-between items-center">
        <h1 class="text-base font-bold text-slate-800">Localización y Emparejamiento de Mascotas</h1>
        <button phx-click="buscar_coincidencias" class="bg-teal-600 hover:bg-teal-700 text-white font-bold px-3 py-1.5 rounded shadow">Buscar Coincidencias (Jaccard &ge; 60%)</button>
      </div>
      <%= if @coincidencias do %>
        <div class="bg-teal-50 border border-teal-300 p-2 rounded">
          <div class="font-bold text-teal-900 mb-1">Similitud Ponderada (&ge; 60%):</div>
          <%= for p <- @coincidencias do %>
            <div class="flex justify-between items-center py-0.5 border-b border-teal-200">
              <div><span class="font-bold text-teal-800">Similitud: {p.puntaje}%</span> | [{p.perdida.id}] {p.perdida.nombre} ({p.perdida.especie}) vs [{p.encontrada.id}] {p.encontrada.nombre}</div>
              <button phx-click="confirmar_coincidencia" phx-value-perdida={p.perdida.id} phx-value-encontrada={p.encontrada.id} class="bg-emerald-600 text-white font-bold px-2 py-0.5 rounded">Confirmar</button>
            </div>
          <% end %>
          <%= if @coincidencias == [] do %><div class="text-teal-700 py-1">Sin coincidencias encontradas con el umbral actual.</div><% end %>
        </div>
      <% end %>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-2.5">
        <form phx-submit="reportar_mascota" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Reportar Mascota</div>
          <select name="tipo" class="w-full border p-1 rounded bg-white"><option value="perdida">Perdida</option><option value="encontrada">Encontrada</option></select>
          <input type="text" name="nombre" placeholder="Nombre (opcional)" class="w-full border p-1 rounded" /><input type="text" name="especie" placeholder="Especie (perro, gato)" required class="w-full border p-1 rounded" /><input type="text" name="color" placeholder="Color (cafe, negro)" required class="w-full border p-1 rounded" />
          <select name="tamano" class="w-full border p-1 rounded bg-white"><option value="pequeno">Pequeño</option><option value="mediano" selected>Mediano</option><option value="grande">Grande</option></select>
          <input type="text" name="zona" placeholder="Zona (Z001)" required class="w-full border p-1 rounded" />
          <button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Guardar Reporte</button>
        </form>
        <div class="bg-white p-2.5 rounded shadow border md:col-span-2 overflow-x-auto max-h-56">
          <div class="flex justify-between items-center mb-1">
            <div class="font-bold text-slate-700">Mascotas Registradas</div>
            <form id="form-filtro-mascotas" phx-change="filtrar" class="flex gap-1">
              <input type="text" name="especie" placeholder="Especie" class="border p-0.5 rounded w-16" /><input type="text" name="zona" placeholder="Zona" class="border p-0.5 rounded w-16" />
              <select name="estado" class="border p-0.5 rounded bg-white"><option value="">Todos</option><option value="activa">Activa</option><option value="posible_coincidencia">Posible Coincidencia</option><option value="resuelta">Resuelta</option></select>
            </form>
          </div>
          <table class="min-w-full divide-y divide-slate-200">
            <thead><tr><th>ID</th><th>Tipo</th><th>Nombre</th><th>Especie</th><th>Color</th><th>Zona</th><th>Autor</th><th>Estado</th></tr></thead>
            <tbody><%= for m <- @mascotas do %><tr class="hover:bg-slate-50">
              <td class="font-mono">{m.id}</td><td class="capitalize">{m.tipo_reporte}</td><td>{m.nombre}</td><td>{m.especie}</td><td>{m.color}</td><td>{m.codigo_zona}</td><td class="text-slate-500 font-mono text-2xs">{m.usuario}</td>
              <td><%= if puede_modificar?(m, @usuario) do %>
                <form id={"form-estado-#{m.id}"} phx-change="actualizar_estado" class="inline"><input type="hidden" name="mascota_id" value={m.id} />
                  <select name="estado" class="border text-2xs p-0.5 rounded bg-white" disabled={m.estado == :resuelta}>
                    <option value="activa" selected={m.estado == :activa}>Activa</option>
                    <option value="posible_coincidencia" selected={m.estado == :posible_coincidencia}>Posible Coincidencia</option>
                    <option value="resuelta" selected={m.estado == :resuelta}>Resuelta</option>
                  </select>
                </form>
              <% else %>
                <span class="capitalize font-semibold text-slate-600">{m.estado}</span>
              <% end %></td>
            </tr><% end %></tbody>
          </table>
        </div>
      </div>
    </main>
    """
  end
end
