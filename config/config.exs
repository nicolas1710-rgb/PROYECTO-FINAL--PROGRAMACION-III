import Config

config :emergencias,
  puerto_usuarios: Emergencias.Infraestructura.Procesos.GestorUsuarios,
  puerto_zonas: Emergencias.Infraestructura.Procesos.GestorZonas,
  puerto_logistica: Emergencias.Infraestructura.Procesos.GestorLogistica,
  puerto_personas: Emergencias.Infraestructura.Procesos.GestorPersonas,
  puerto_mascotas: Emergencias.Infraestructura.Procesos.GestorMascotas,
  puerto_albergues: Emergencias.Infraestructura.Procesos.SupervisorAlbergues,
  puerto_bitacora: Emergencias.Infraestructura.Procesos.Bitacora,
  directorio_datos: "datos"

config :emergencias, EmergenciasWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EmergenciasWeb.ErrorHTML, json: EmergenciasWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Emergencias.PubSub,
  live_view: [signing_salt: "yLiRbnc9"]

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.25.0",
  emergencias: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.3.0",
  emergencias: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/css/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
