defmodule AmqpPubsub.EventForwarder do
  require Logger
  use GenEvent

  def handle_event(event, parent) do
    Logger.debug "!Event from #{inspect parent}! #{inspect event}"
    send parent, event
    {:ok, parent}
  end
end

defmodule AmqpPubsub do
  use Application

  @manager_name AmqpPubsub.EventManager
  @registry_name AmqpPubsub.Registry
  @ets_registry_name AmqpPubsub.Registry
  @worker_sup_name AmqpPubsub.Worker.Supervisor
  @oauth_jwt_worker OauthJwt.Client
  @reverse_proxy_name AmqpPubsub.ReverseProxy

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    ets = :ets.new(@ets_registry_name,
                       [:set, :public, :named_table, {:read_concurrency, true}])



    children = [
      # Define workers and child supervisors to be supervised
      # worker(AmqpPubsub.Worker, [arg1, arg2, arg3]),
      worker(OauthJwt.Client, [[], [name: @oauth_jwt_worker]]),
      worker(GenEvent, [[name: @manager_name]]),
      supervisor(AmqpPubsub.Worker.Supervisor, [[name: @worker_sup_name]]),
      worker(AmqpPubsub.Registry, [ets, @manager_name, @worker_sup_name, [name: @registry_name]]),
      worker(AmqpPubsub.ReverseProxy, [[name: @reverse_proxy_name]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_all, name: AmqpPubsub.Supervisor]
    Supervisor.start_link(children, opts)
    #resp = Supervisor.start_link(children, opts)
    #GenEvent.add_mon_handler(@manager_name, AmqpPubsub.EventForwarder, self())
    #resp
  end
end
