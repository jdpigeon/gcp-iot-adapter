defmodule AmqpPubsub.Worker do
  alias AmqpPubsub.Google.Pubsub
  require Logger
  use GenServer
  use AMQP

  @max_message_batch_size 500
  @prefetch_count 1500

  @doc """
  Starts a new worker.
  """
  def start_link(connection, route, opts \\ []) do
    #Agent.start_link(fn -> HashDict.new end)
    GenServer.start_link(__MODULE__, {connection, route}, opts)
  end

  def init({connection = %{conn: conn, chan: chan}, route = %{route: route_config, amqp_subscription: amqp_subscription, subscription_name: subscription_name}}) do
    #Process.flag(:trap_exit, true)
    exchange = Application.get_env(:amqp_pubsub, :ampq_exchange)
    # use subscription path as Queue name
    queue = route_config
    if Application.get_env(:amqp_pubsub, :ampq_exchange) != false do
      Queue.declare(chan, queue, durable: true)
      #routing_key = subscription |> String.replace("/", ".") |> String.replace("+", "*")
      routing_key = amqp_subscription
      Queue.bind(chan, queue, exchange, routing_key: routing_key)
    end

    Pubsub.create_cloud_pubsub_topic(subscription_name)

    {:ok, consumer_tag} = Basic.consume(chan, queue)

    cache = []
    cache_count = 0

    schedule_work(1000)

    {:ok, %{conn: conn, chan: chan, route: route, cache: cache, cache_count: cache_count}}
  end

  defp schedule_work(delay \\ 500) do
    Process.send_after(self(), :work, delay)
  end

  defp do_work(state) do
    spawn(fn -> flush_cache(state) end)
    #delay = if state.cache_count >= @max_message_batch_size, do: 10, else: 100
    #delay = case state.cache_count do
    #  0 -> 200
    #  cache_count -> (@prefetch_count/cache_count)*10
    #end |> round
    delay = 10
    schedule_work(delay)
  end

  defp flush_cache(state) do
    #Logger.debug "cache: #{inspect state.cache}"
    #for messages <- Enum.chunk(state.cache, @max_message_batch_size, @max_message_batch_size, []) do
      #messages_size = Enum.count messages
      #timestamp = Timex.Date.local |> Timex.DateFormat.format!("{ISO}")
      #Logger.debug ("#{state.route.route} -> #{state.route.subscription_name}: Sending #{messages_size} messages to PubSub")
    #  spawn(fn -> publish(state, messages) end)
    #end
    state.cache
    |> Stream.chunk(@max_message_batch_size, @max_message_batch_size, [])
    |> Stream.map(fn(messages) -> spawn(fn -> publish(state, messages) end) end)
    |> Stream.run
  end

  defp publish(state = %{chan: channel, route: %{subscription_name: pubsub_topic}}, messages) do
    # TODO: reduce/fold on the fly instead of unzipping afterwards
    {pubsub_messages, tags} = Enum.unzip(for {payload, _meta = %{delivery_tag: tag, routing_key: topic}} <- messages do
      topic_params = AmqpPubsub.Route.parse_topic_parameters(topic, state.route.topic_parser_config) |> Map.new |> Poison.encode!
      {Pubsub.assemble_pubsub_message(payload, %{"mqtt_topic": topic |> String.replace(".", "/"), "mqtt_topic_params": topic_params}), tag}
    end)

    pubsub_body = %{"messages" => pubsub_messages}
    #Logger.debug "Pubsub Messages: #{inspect pubsub_body}"

    Logger.debug "Publishing #{Enum.count(messages)} messages to #{pubsub_topic}."
    #:timer.sleep(100)
    #case {:ok, %{status_code: 200}} do
    case Pubsub.publish(pubsub_topic, pubsub_body) do
      {:ok, %{status_code: 200}} ->
        for tag <- tags do
          # IO.puts "acking: #{inspect tag}"
          Basic.ack(channel, tag)
        end
      response ->
        Logger.debug "Failed PubSub publish!\n Response: #{inspect response}"
        for tag <- tags do
          Basic.reject(channel, tag)
        end
    end
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, meta = %{delivery_tag: tag, redelivered: redelivered, routing_key: topic}}, state) do
    #IO.puts "meta: #{inspect meta}"
    #spawn fn -> consume(chan, tag, redelivered, payload, topic) end
    #Basic.ack(state.chan, tag)
    new_cache = [{payload, meta} | state.cache]
    new_cache_count = state.cache_count + 1
    new_state = %{state | cache: new_cache, cache_count: new_cache_count}

    #IO.inspect Enum.count(new_cache)

    {:noreply, new_state}
  end

  def handle_info(:work, state) do
    do_work(state)
    # reset cache
    new_state = %{state | cache: [], cache_count: 0}
    {:noreply, new_state}
  end

  def handle_info({:EXIT, from, reason}, state) do
   Logger.debug "Worker received :EXIT from #{inspect from} with reason: #{inspect reason}"
   {:noreply, state}
  end

  def handle_info(msg, state) do
   Logger.debug "Worker received other message: #{inspect msg}\nstate: #{inspect state}"
   {:noreply, state}
  end

end
