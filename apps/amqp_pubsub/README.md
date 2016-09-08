# AmqpPubsub

Proxies MQTT topics through RabbitMQ broker to Google Cloud Pub Sub.

## Development
Ensure you have Erlang 18.2 and Elixir 1.2 installed. After grabbing the source, enter run (in the amqp_pubsub app):

```
mix deps.get
mix deps.compile
```

## Build
Note: by default, the config environment is set to "dev".

To build amqp_pubsub:

```
mix compile
```

To do a release:

```
mix release
```

To build against prod configuration, compile the project first with prod settings, then do a release :

```
export MIX_ENV=prod
mix compile
mix release
```

To run in interactive shell:

```
iex -S mix
```



## Installation

In `rel/amqp_pubsub/releases/x.y.z`, grab the `amqp_ubsub.tar.gz` file and unpack that to the installation site.

Modify the config file `releases/0.0.1/amqp_pubsub.conf` as needed.

The executable is located at `bin/amqp_pubsub`.
