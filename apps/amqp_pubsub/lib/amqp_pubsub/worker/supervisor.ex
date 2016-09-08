defmodule AmqpPubsub.Worker.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def start_worker(supervisor, connection, subscription) do
    Supervisor.start_child(supervisor, [connection, subscription])
  end

  def init(:ok) do
    children = [
      worker(AmqpPubsub.Worker, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
