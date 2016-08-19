defmodule AmqpPubsub.Main do

  def main(args) do
    run()
    :timer.sleep(:infinity)
  end

  def run() do
    AmqpPubsub.Registry.add_routes_from_config(AmqpPubsub.Registry)
  end
end