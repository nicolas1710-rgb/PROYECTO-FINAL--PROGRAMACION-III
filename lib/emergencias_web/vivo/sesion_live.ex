defmodule EmergenciasWeb.Vivo.SesionLive do
  @moduledoc "LiveView de autenticacion y seleccion de rol para acceder al sistema."
  use EmergenciasWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, formulario: to_form(%{"usuario" => "", "clave" => "", "rol" => "coordinador", "zona" => "Z001"}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-100 flex flex-col justify-center py-10 px-4 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <div class="text-center">
          <span class="inline-block p-3 rounded-full bg-red-100 text-red-600 text-2xl font-black">EMG</span>
          <h2 class="mt-3 text-2xl font-black text-slate-900 tracking-tight">Gestión de Emergencias</h2>
          <p class="mt-1 text-xs text-slate-600">Sistema Distribuido — Terremoto Quindío 2026</p>
        </div>
        <div class="mt-6 bg-white py-6 px-6 shadow rounded-lg border border-slate-200">
          <form action={~p"/sesion/iniciar"} method="post" class="space-y-4 text-xs">
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <div>
              <label class="block font-medium text-slate-700">Nombre de Usuario</label>
              <input type="text" name="usuario" required placeholder="Ej: Laura o Carlos" class="mt-1 w-full rounded border-slate-300 p-1.5 border" />
            </div>
            <div>
              <label class="block font-medium text-slate-700">Contraseña</label>
              <input type="password" name="clave" required placeholder="Clave de acceso" class="mt-1 w-full rounded border-slate-300 p-1.5 border" />
            </div>
            <div>
              <label class="block font-medium text-slate-700">Rol Operativo</label>
              <select name="rol" class="mt-1 w-full rounded border-slate-300 p-1.5 border bg-white">
                <option value="coordinador">Coordinador (Gestión total)</option>
                <option value="voluntario">Voluntario (Suministros y albergues)</option>
                <option value="ciudadano">Ciudadano (Reportes y consultas)</option>
                <option value="administrador">Administrador</option>
              </select>
            </div>
            <div>
              <label class="block font-medium text-slate-700">Zona Inicial</label>
              <input type="text" name="zona" value="Z001" placeholder="Ej: Z001" class="mt-1 w-full rounded border-slate-300 p-1.5 border" />
            </div>
            <button type="submit" class="w-full py-2 px-4 rounded text-white bg-slate-800 hover:bg-slate-900 font-bold transition">
              Ingresar al Sistema
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
