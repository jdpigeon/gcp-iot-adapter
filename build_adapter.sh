set -e

# simple script to build the adapter and copy the tarball to the root of the project
# Used by the build_with_docker script.

echo "Building the adapter.."

export BUILD_VER=$(grep version apps/amqp_pubsub/mix.exs | sed 's/[^0-9.]//g')

mix local.hex --force
mix local.rebar --force
mix deps.get
(cd apps/amqp_pubsub && MIX_ENV=prod mix do deps.compile, compile, release)
cp apps/amqp_pubsub/rel/amqp_pubsub/releases/${BUILD_VER}/amqp_pubsub.tar.gz .

echo "Adapter built, file amqp_pubsub.tar.gz in this directory."

echo "Making .deb now.."
./build_deb.sh
