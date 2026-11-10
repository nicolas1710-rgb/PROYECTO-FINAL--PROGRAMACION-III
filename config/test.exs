import Config

config :emergencias, EmergenciasWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "nwxVvRLnUihVvT1MbMTp2kbhhYK5kPQ2kVwPeQHxhVLsQt0Az/8DF/3H1tozlimk",
  server: false

config :logger, level: :warning
