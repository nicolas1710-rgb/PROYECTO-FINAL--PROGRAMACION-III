defmodule EmergenciasWeb.Vivo.FamiliaresLive do
  @moduledoc "LiveView de censo de personas damnificadas, busqueda flexible y mensajeria familiar."
  use EmergenciasWeb, :live_view
  alias Emergencias.Aplicacion.CasosUso.GestionarFamiliares
  alias Emergencias.Infraestructura.MensajesError
  alias EmergenciasWeb.Componentes.Navegacion
  alias EmergenciasWeb.Notificador

  @impl true
  def mount(_p, _s, socket) do
    if connected?(socket), do: Notificador.suscribir()
    {:ok, socket |> assign(personas: [], doc_activo: nil, mensajes: []) |> cargar_personas()}
  end

  @impl true
  def handle_event("reportar_persona", %{"doc" => d, "nombre" => n, "edad" => e, "zona" => z, "estado" => est}, s),
    do: dar_respuesta(s, GestionarFamiliares.reportar_persona(d, n, e, z, est, s.assigns.usuario), "Persona reportada.")
  def handle_event("actualizar_estado", %{"doc" => d, "estado" => est}, s),
    do: dar_respuesta(s, GestionarFamiliares.actualizar_persona(d, est, s.assigns.usuario), "Estado actualizado.")
  def handle_event("seleccionar_persona", %{"doc" => d}, socket) do
    {:ok, ms} = GestionarFamiliares.listar_mensajes(d, socket.assigns.usuario)
    {:noreply, assign(socket, doc_activo: d, mensajes: ms)}
  end
  def handle_event("enviar_mensaje", %{"doc" => d, "contenido" => msg}, socket) do
    u = socket.assigns.usuario
    dar_respuesta(socket, GestionarFamiliares.enviar_mensaje(d, u.nombre, msg, u), "Mensaje enviado.")
  end
  def handle_event("buscar_persona", %{"criterio" => c}, socket) do
    crit = String.trim(c)
    case GestionarFamiliares.buscar_persona(if(crit == "", do: %{}, else: crit), socket.assigns.usuario) do
      {:ok, %{} = p} -> {:noreply, assign(socket, personas: [p])}
      {:ok, list} when is_list(list) -> {:noreply, assign(socket, personas: list)}
      {:error, r} -> {:noreply, socket |> put_flash(:error, MensajesError.obtener_mensaje(r)) |> assign(personas: [])}
    end
  end

  @impl true
  def handle_info({:cambio, _tema}, socket), do: {:noreply, cargar_personas(socket)}

  defp dar_respuesta(socket, resultado, mensaje_ok) do
    case resultado do
      {:ok, _} ->
        Notificador.difundir_cambio(:familiares)
        doc = socket.assigns.doc_activo
        ms = if doc, do: (case GestionarFamiliares.listar_mensajes(doc, socket.assigns.usuario) do {:ok, l} -> l; _ -> [] end), else: []
        {:noreply, socket |> put_flash(:info, mensaje_ok) |> assign(mensajes: ms) |> cargar_personas()}
      {:error, r} -> {:noreply, put_flash(socket, :error, MensajesError.obtener_mensaje(r))}
    end
  end

  defp cargar_personas(socket) do
    case GestionarFamiliares.buscar_persona(%{}, socket.assigns.usuario) do
      {:ok, list} when is_list(list) -> assign(socket, personas: list)
      _ -> assign(socket, personas: [])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Navegacion.barra_superior usuario={@usuario} flash={@flash} pagina_activa="familiares" />
    <main class="max-w-7xl mx-auto px-4 py-2 space-y-3 text-xs">
      <div class="bg-white p-2.5 rounded shadow border flex justify-between items-center">
        <h1 class="text-base font-bold text-slate-800">Censo y Mensajería Familiar</h1>
        <form phx-submit="buscar_persona" class="flex gap-1">
          <input type="text" name="criterio" placeholder="Doc, nombre o zona..." class="border p-1 rounded w-48" />
          <button type="submit" class="bg-slate-800 text-white px-3 py-1 rounded">Buscar</button>
        </form>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-2.5">
        <form phx-submit="reportar_persona" class="bg-white p-2.5 rounded shadow border space-y-1">
          <div class="font-bold text-slate-700">Registrar en Censo</div>
          <input type="text" name="doc" placeholder="Documento" required class="w-full border p-1 rounded" /><input type="text" name="nombre" placeholder="Nombre completo" required class="w-full border p-1 rounded" /><input type="number" name="edad" placeholder="Edad" required min="0" class="w-full border p-1 rounded" /><input type="text" name="zona" placeholder="Zona (Z001)" required class="w-full border p-1 rounded" />
          <select name="estado" class="w-full border p-1 rounded bg-white"><option value="reportada">Reportada</option><option value="localizada">Localizada</option><option value="en_albergue">En Albergue</option><option value="trasladada">Trasladada</option></select>
          <button type="submit" class="w-full bg-slate-800 text-white py-1 rounded">Guardar Registro</button>
        </form>
        <div class="bg-white p-2.5 rounded shadow border md:col-span-2 overflow-x-auto max-h-56">
          <div class="font-bold text-slate-700 mb-1">Personas Censadas</div>
          <table class="min-w-full divide-y divide-slate-200">
            <thead><tr><th>Doc</th><th>Nombre</th><th>Edad</th><th>Zona</th><th>Estado</th><th>Acciones</th></tr></thead>
            <tbody><%= for p <- @personas do %>
              <tr class={["hover:bg-slate-50", if(@doc_activo == p.documento, do: "bg-blue-50")]}>
                <td class="font-mono">{p.documento}</td><td>{p.nombre}</td><td>{p.edad}</td><td>{p.zona}</td>
                <td><form phx-change="actualizar_estado" class="inline"><input type="hidden" name="doc" value={p.documento} />
                  <select name="estado" class="border text-2xs p-0.5 rounded bg-white">
                    <option value="reportada" selected={to_string(p.estado) == "reportada"}>Reportada</option><option value="localizada" selected={to_string(p.estado) == "localizada"}>Localizada</option><option value="en_albergue" selected={to_string(p.estado) == "en_albergue"}>En Albergue</option><option value="trasladada" selected={to_string(p.estado) == "trasladada"}>Trasladada</option>
                  </select>
                </form></td>
                <td><button phx-click="seleccionar_persona" phx-value-doc={p.documento} class="text-blue-600 hover:underline">Mensajes</button></td>
              </tr>
            <% end %></tbody>
          </table>
        </div>
      </div>
      <%= if @doc_activo do %>
        <div class="bg-white p-2.5 rounded shadow border space-y-2">
          <div class="font-bold text-slate-800">Mensajes para Documento: <span class="font-mono text-blue-700">{@doc_activo}</span></div>
          <form phx-submit="enviar_mensaje" class="flex gap-2">
            <input type="hidden" name="doc" value={@doc_activo} /><input type="text" name="contenido" placeholder="Escribir mensaje familiar..." required class="border p-1 rounded flex-1" />
            <button type="submit" class="bg-blue-600 text-white px-3 py-1 rounded font-bold">Enviar</button>
          </form>
          <div class="space-y-1 max-h-36 overflow-y-auto">
            <%= for m <- @mensajes do %><div class="p-1 bg-slate-50 rounded border"><span class="font-bold">{m.remitente}:</span> {m.contenido} <span class="text-2xs text-slate-400 float-right">{m.fecha}</span></div><% end %>
            <%= if @mensajes == [] do %><div class="text-slate-400 py-1">Sin mensajes registrados.</div><% end %>
          </div>
        </div>
      <% end %>
    </main>
    """
  end
end
