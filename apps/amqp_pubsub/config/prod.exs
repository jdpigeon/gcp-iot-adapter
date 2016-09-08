use Mix.Config

config :amqp_pubsub, :ampq_conn_options,
  host: "localhost",
  port: 5672,
  username: "test",
  password: "testpass"

config :logger, level: :info
