@moduledoc """
A schema is a keyword list which represents how to map, transform, and validate
configuration values parsed from the .conf file. The following is an explanation of
each key in the schema definition in order of appearance, and how to use them.

## Import

A list of application names (as atoms), which represent apps to load modules from
which you can then reference in your schema definition. This is how you import your
own custom Validator/Transform modules, or general utility modules for use in
validator/transform functions in the schema. For example, if you have an application
`:foo` which contains a custom Transform module, you would add it to your schema like so:

`[ import: [:foo], ..., transforms: ["myapp.some.setting": MyApp.SomeTransform]]`

## Extends

A list of application names (as atoms), which contain schemas that you want to extend
with this schema. By extending a schema, you effectively re-use definitions in the
extended schema. You may also override definitions from the extended schema by redefining them
in the extending schema. You use `:extends` like so:

`[ extends: [:foo], ... ]`

## Mappings

Mappings define how to interpret settings in the .conf when they are translated to
runtime configuration. They also define how the .conf will be generated, things like
documention, @see references, example values, etc.

See the moduledoc for `Conform.Schema.Mapping` for more details.

## Transforms

Transforms are custom functions which are executed to build the value which will be
stored at the path defined by the key. Transforms have access to the current config
state via the `Conform.Conf` module, and can use that to build complex configuration
from a combination of other config values.

See the moduledoc for `Conform.Schema.Transform` for more details and examples.

## Validators

Validators are simple functions which take two arguments, the value to be validated,
and arguments provided to the validator (used only by custom validators). A validator
checks the value, and returns `:ok` if it is valid, `{:warn, message}` if it is valid,
but should be brought to the users attention, or `{:error, message}` if it is invalid.

See the moduledoc for `Conform.Schema.Validator` for more details and examples.
"""
[
  extends: [],
  import: [],
  mappings: [
    "logger.level": [
      commented: false,
      datatype: :atom,
      default: :debug,
      doc: "Log level",
      hidden: false,
      to: "logger.level"
    ],
    "oauth_jwt.secrets_file": [
      commented: false,
      datatype: :binary,
      default: "client_secrets.json",
      doc: "Path to Google service account JSON file.",
      hidden: false,
      to: "oauth_jwt.secrets_file"
    ],
    "oauth_jwt.use_default_service_account": [
      commented: false,
      datatype: :atom,
      default: true,
      doc: "Use the default service account from metadata server if available (when running on GCE).",
      hidden: false,
      to: "oauth_jwt.use_default_service_account"
    ],
    "amqp_pubsub.ampq_exchange": [
      commented: false,
      datatype: :binary,
      default: "amq.topic",
      doc: "AMQP exchange that the MQTT plugin is configured to use.",
      hidden: false,
      to: "amqp_pubsub.ampq_exchange"
    ],
    "amqp_pubsub.pubsub_project_prefix": [
      commented: false,
      datatype: :binary,
      default: "projects/your-gcp-project/",
      doc: "Project prefix for topics and subscriptions. Currently of the form projects/{project-id}/",
      hidden: false,
      to: "amqp_pubsub.pubsub_project_prefix"
    ],
    "amqp_pubsub.disable_queue_creation": [
      commented: false,
      datatype: :atom,
      default: false,
      doc: "Disables creation of queues in RabbitMQ for the proxied routes.",
      hidden: false,
      to: "amqp_pubsub.disable_queue_creation"
    ],
    "amqp_pubsub.ampq_conn_options.host": [
      commented: false,
      datatype: :binary,
      default: "localhost",
      doc: "RabbitMQ host.",
      hidden: false,
      to: "amqp_pubsub.ampq_conn_options.host"
    ],
    "amqp_pubsub.ampq_conn_options.port": [
      commented: false,
      datatype: :integer,
      default: 5672,
      doc: "RabbitMQ connection port.",
      hidden: false,
      to: "amqp_pubsub.ampq_conn_options.port"
    ],
    "amqp_pubsub.ampq_conn_options.username": [
      commented: false,
      datatype: :binary,
      default: "test",
      doc: "RabbitMQ username.",
      hidden: false,
      to: "amqp_pubsub.ampq_conn_options.username"
    ],
    "amqp_pubsub.ampq_conn_options.password": [
      commented: false,
      datatype: :binary,
      default: "testpass",
      doc: "RabbitMQ password.",
      hidden: false,
      to: "amqp_pubsub.ampq_conn_options.password"
    ],
    "amqp_pubsub.routes": [
      commented: false,
      datatype: [
        list: [
          list: {:atom, :binary}
        ]
      ],
      default: [
        [route: "gateway/#", name: "gateways"], []
      ],
      doc: "MQTT topics to forward to Google Cloud PubSub. Wildcards can have an assoicated name to be parsed and forwarded as metadata in the PubsubMessage, otherwise a default name will be used.",
      hidden: false,
      to: "amqp_pubsub.routes"
    ],
    "amqp_pubsub.reverse_subscription": [
      commented: false,
      datatype: :binary,
      default: "rabbitmq-proxy",
      doc: "Google Cloud Pub/Sub subscription name for messages intended to be relayed to the adapter.",
      hidden: false,
      to: "amqp_pubsub.reverse_subscription"
    ],
    "amqp_pubsub.reverse_topic": [
      commented: false,
      datatype: :binary,
      default: "to-gateway",
      doc: "Google Cloud Pub/Sub topic for messages intended to be relayed to the adapter.",
      hidden: false,
      to: "amqp_pubsub.reverse_topic"
    ],
  ],
  transforms: [],
  validators: []
]
