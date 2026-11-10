import Config

config :emergencias, EmergenciasWeb.Endpoint,
  http: [port: 4000],
  secret_key_base: "RrUEpDOvkzQdjALex/rDKsVGJTzkHLGAEMgmpgHDqV0HelfYhXNLsfCNbi8AJPdt",
  server: true

config :logger, level: :info
