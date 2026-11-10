import Config

config :emergencias, EmergenciasWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "RrUEpDOvkzQdjALex/rDKsVGJTzkHLGAEMgmpgHDqV0HelfYhXNLsfCNbi8AJPdt",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:emergencias, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:emergencias, ~w(--watch)]}
  ]

config :logger, level: :info
