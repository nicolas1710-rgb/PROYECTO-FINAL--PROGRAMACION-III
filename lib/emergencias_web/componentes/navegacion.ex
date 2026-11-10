defmodule EmergenciasWeb.Componentes.Navegacion do
  @moduledoc "Barra superior de navegacion unificada para las vistas del sistema."
  use Phoenix.Component
  use EmergenciasWeb, :verified_routes

  attr :usuario, :map, required: true
  attr :pagina_activa, :string, default: ""
  attr :flash, :map, default: %{}

  def barra_superior(assigns) do
    ~H"""
    <header class="bg-slate-800 text-white shadow mb-3">
      <div class="max-w-7xl mx-auto px-4 py-2.5 flex flex-wrap items-center justify-between gap-3">
        <div class="flex items-center gap-2">
          <span class="text-lg font-black tracking-tight text-red-400">EMERGENCIAS</span>
          <span class="text-2xs bg-slate-700 px-2 py-0.5 rounded text-slate-300">Quindío 2026</span>
        </div>
        <nav class="flex flex-wrap items-center gap-1 text-xs font-medium">
          <%= for {r, e, c} <- [{~p"/resumen", "Resumen", "resumen"}, {~p"/logistica", "Logística", "logistica"}, {~p"/zonas", "Zonas", "zonas"}, {~p"/familiares", "Familiares", "familiares"}, {~p"/mascotas", "Mascotas", "mascotas"}, {~p"/albergues", "Albergues", "albergues"}] do %>
            <.enlace_nav ruta={r} actual={@pagina_activa == c} etiqueta={e} />
          <% end %>
        </nav>
        <div class="flex items-center gap-3 text-xs">
          <div class="text-right">
            <div class="font-bold text-slate-100">{@usuario.nombre}</div>
            <div class="text-2xs text-amber-300 capitalize">{@usuario.rol}</div>
          </div>
          <a href={~p"/sesion/cerrar"} class="bg-red-600 hover:bg-red-700 text-white text-2xs px-2.5 py-1 rounded transition">Salir</a>
        </div>
      </div>
    </header>
    <%= if msg = Phoenix.Flash.get(@flash, :error) do %><div class="max-w-7xl mx-auto px-4 mb-2"><div class="bg-red-100 border-l-4 border-red-500 text-red-800 p-2 text-xs rounded">{msg}</div></div><% end %>
    <%= if msg = Phoenix.Flash.get(@flash, :info) do %><div class="max-w-7xl mx-auto px-4 mb-2"><div class="bg-emerald-100 border-l-4 border-emerald-500 text-emerald-800 p-2 text-xs rounded">{msg}</div></div><% end %>
    """
  end

  defp enlace_nav(assigns) do
    ~H"""
    <a href={@ruta} class={["px-2.5 py-1 rounded transition", if(@actual, do: "bg-slate-900 text-amber-400 font-bold", else: "text-slate-300 hover:bg-slate-700")]}>{@etiqueta}</a>
    """
  end
end
