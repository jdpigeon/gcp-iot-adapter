use Mix.Config

config :amqp_pubsub, :routes, [
  [route: "gateway/#", name: "gateway_log"], []
  ]
