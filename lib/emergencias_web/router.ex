defmodule EmergenciasWeb.Router do
  @moduledoc "Enrutador Phoenix para la interfaz web de emergencias."
  use EmergenciasWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EmergenciasWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", EmergenciasWeb do
    pipe_through :browser
    post "/sesion/iniciar", SesionController, :iniciar
    get "/sesion/cerrar", SesionController, :cerrar

    live_session :publico, on_mount: [{EmergenciasWeb.Sesion, :redirigir_autenticado}] do
      live "/", Vivo.SesionLive, :index
    end

    live_session :protegido, on_mount: [{EmergenciasWeb.Sesion, :exigir_sesion}] do
      live "/resumen", Vivo.ResumenLive, :index
      live "/logistica", Vivo.LogisticaLive, :index
      live "/zonas", Vivo.ZonasLive, :index
      live "/familiares", Vivo.FamiliaresLive, :index
      live "/mascotas", Vivo.MascotasLive, :index
      live "/albergues", Vivo.AlberguesLive, :index
    end
  end
end
