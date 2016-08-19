# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :amqp_pubsub, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:amqp_pubsub, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

config :amqp_pubsub, :ampq_conn_options,
  host: "localhost",
  port: 5672,
  username: "test",
  password: "test"

config :amqp_pubsub, ampq_exchange: "amq.topic"
config :amqp_pubsub, pubsub_project_prefix: "projects/hmi-twisthink-poc/"
config :amqp_pubsub, disable_queue_creation: false


config :logger, level: :debug

config :oauth_jwt, secrets_file: "client_secrets.json"
config :oauth_jwt, use_default_service_account: true


import_config "#{Mix.env}.exs"

import_config "routes.exs"


system_env = [
  amqp_pubsub: [
    host: "AMQP_PUBSUB_RMQ_HOST",
    port: "AMQP_PUBSUB_RMQ_PORT",
    username: "AMQP_PUBSUB_RMQ_USERNAME",
    password: "AMQP_PUBSUB_RMQ_PASSWORD",
    exchange: "AMQP_PUBSUB_RMQ_EXCHANGE",
    full_topic_path: "AMQP_PUBSUB_GCP_PS_TOPIC"
  ],
  oauth_jwt: [
    secrets_file: "AMQP_PUBSUB_OAUTH_CLIENT_SECRETS_FILE",
    user_default_service_account: "AMQP_PUBSUB_OAUTH_USE_DEFAULT_SERVICE_ACCOUNT"
  ]
]
