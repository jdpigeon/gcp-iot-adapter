defmodule AmqpPubsub.Registry do
  require Logger
  use GenServer
  alias AmqpPubsub.Worker

  @prefetch_count 1500

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(table, event_manager, workers, opts \\ []) do
    # 1. We now expect the table as argument and pass it to the server
    {:ok, pid} = GenServer.start_link(__MODULE__, {table, event_manager, workers}, opts)
    add_routes_from_config(pid)
    {:ok, pid}
  end

  @doc """
  Looks up the worker pid for `name` stored in `table`.

  Returns `{:ok, pid}` if a worker exists, `:error` otherwise.
  """
  def lookup(table, name) do
    # 2. lookup now expects a table and looks directly into ETS.
    #    No request is sent to the server.
    case :ets.lookup(table, name) do
      [{^name, worker}] -> {:ok, worker}
      [] -> :error
    end
  end

  def create(server, route = %{}) do
    GenServer.call(server, {:create, route})
  end

  def add_routes_from_config(server) do
    routes = AmqpPubsub.Route.create_routes()
    for route <- routes do
      create(server, route)
    end
  end

  #@doc """
  #Ensures there is a worker associated with the given `name` in `server`.
  #
  #Name should be the MQTT subscription path.
  #"""
  #def create(server, name) do
  #  GenServer.call(server, {:create, name})
  #end

  ## Server callbacks

  def init({table, events, workers}) do
    #Process.flag(:trap_exit, true)
    connection = open_amqp_connection()
    conn_pid = connection.conn.pid
    chan_pid = connection.chan.pid
    #amqp_monitor = Process.monitor(conn_pid)
    #channel_monitor = Process.monitor(chan_pid)
    Process.link(conn_pid)
    Process.link(chan_pid)


    Logger.debug "connection: #{inspect connection}"
    Logger.debug "Connection PID is: #{inspect conn_pid}"
    Logger.debug "Channel PID is: #{inspect chan_pid}"
    #amqp_monitor = :erlang.monitor :process, connection["conn"]["pid"]
    #channel_monitor = :erlang.monitor :process, connection["chan"]["pid"]

    refs = :ets.foldl(fn {name, pid}, acc ->
      # TODO: update Worker amqp connection/channel
      # I think we'd have to restart the process anyways...
      # TODO: Explore exchange-to-exchange bindings for future performance improvements
      # Worker.update_amqp(pid, connection)
      HashDict.put(acc, Process.monitor(pid), name)
    end, HashDict.new, table)

    {:ok, %{names: table, refs: refs, events: events, workers: workers, connection: connection}} #, amqp_monitor_ref: amqp_monitor, channel_monitor_ref: channel_monitor}}
  end

  @doc """
  Opens connection to AMQP server and creates an AMQP channel.
  """
  def open_amqp_connection() do
    conn_options = Application.get_env(:amqp_pubsub, :ampq_conn_options)

    {:ok, conn} = AMQP.Connection.open conn_options
    {:ok, chan} = AMQP.Channel.open(conn)
    AMQP.Basic.qos(chan, prefetch_count: @prefetch_count)
    %{conn: conn, chan: chan}
  end

  # 4. The previous handle_call callback for lookup was removed

  #def handle_call({:create, name}, _from, state) do
  #  case lookup(state.names, name) do
  #    {:ok, pid} ->
  #      {:reply, pid, state} # Reply with pid
  #    :error ->
  #      {:ok, pid} = Worker.Supervisor.start_worker(state.workers, state.connection, name)
  #      ref = Process.monitor(pid)
  #      refs = HashDict.put(state.refs, ref, name)
  #      :ets.insert(state.names, {name, pid})
  #      GenEvent.sync_notify(state.events, {:create, name, pid})
  #      {:reply, pid, %{state | refs: refs}} # Reply with pid
  #  end
  #end

  def handle_call({:create, route = %{route: name}}, _from, state) do
    case lookup(state.names, name) do
      {:ok, worker_info = {pid, ^route}} ->
        {:reply, worker_info, state}

      {:ok, {pid, cached_route}} ->
        raise "can't create route that exists in cache with new route:\nnew route #{inspect route}\nold route #{inspect cached_route}"

      :error ->
        {:ok, pid} = Worker.Supervisor.start_worker(state.workers, state.connection, route)
        ref = Process.monitor(pid)
        refs = HashDict.put(state.refs, ref, name)
        worker_info = {pid, route}
        :ets.insert(state.names, {name, {pid, route}})
        GenEvent.sync_notify(state.events, {:create, name, pid})
        {:reply, worker_info, %{state | refs: refs}} # Reply with pid
    end
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    # 6. Delete from the ETS table instead of the HashDict
    {name, refs} = HashDict.pop(state.refs, ref)
    worker_info = lookup(state.names, name)
    Logger.info "Worker died: #{inspect worker_info} with reason #{inspect reason}"
    Logger.info "self: #{inspect self}"
    Logger.info "#{inspect {:DOWN, ref, :process, pid, reason}}"
    Logger.info "#{inspect state}"
    :ets.delete(state.names, name)
    GenEvent.sync_notify(state.events, {:exit, name, pid})
    {:noreply, %{state | refs: refs}}
  end

  def handle_info({:EXIT, from, reason}, state) do
    Logger.debug "Registry received :EXIT from #{inspect from} with reason: #{inspect reason}"
    {:noreply, state}
  end


  def handle_info(msg, state) do
    Logger.debug "Registry received other message: #{inspect msg}\nstate: #{inspect state}"
    {:noreply, state}
  end
end
