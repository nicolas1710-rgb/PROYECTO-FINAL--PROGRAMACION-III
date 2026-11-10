defmodule EmergenciasWeb.Endpoint do
  @moduledoc "Endpoint HTTP para la interfaz web Phoenix LiveView."
  use Phoenix.Endpoint, otp_app: :emergencias

  @session_options [
    store: :cookie,
    key: "_emergencias_key",
    signing_salt: "7LYX7PWO",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :emergencias,
    gzip: false,
    only: EmergenciasWeb.static_paths()

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug EmergenciasWeb.Router

  @doc "Opciones de sesion para pruebas y adaptadores."
  def session_options, do: @session_options
end
