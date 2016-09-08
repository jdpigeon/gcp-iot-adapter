defmodule AmqpPubsub.ReverseProxy do
  require Logger
  use GenServer
  use AMQP
  alias AmqpPubsub.Google.Pubsub


  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(_opts) do
    conn_options = Application.get_env(:amqp_pubsub, :ampq_conn_options)

    Logger.info "ampq conn options: #{inspect conn_options}"
    {:ok, conn} =  AMQP.Connection.open conn_options
    {:ok, chan} = Channel.open(conn)
    Basic.qos(chan, prefetch_count: 10)

    Pubsub.create_cloud_pubsub_topic(Application.get_env(:amqp_pubsub, :reverse_topic))
    Pubsub.create_subscription(Application.get_env(:amqp_pubsub, :reverse_subscription), Application.get_env(:amqp_pubsub, :reverse_topic))

    schedule_work()
    {:ok, chan}
  end

  def handle_info(:work, chan) do
    do_work(chan)
    {:noreply, chan}
  end

  defp do_work(chan) do
    body = %{ "returnImmediately" => false,
              "maxMessages" => 30 }
    acks = case Pubsub.pull_subscription(Application.get_env(:amqp_pubsub, :reverse_subscription), body, recv_timeout: :infinity) do
      {:ok, resp} ->
        case (resp.body |> Poison.decode!)["receivedMessages"] do
          messages when is_list(messages) ->
            for receivedMessage = %{"ackId" => ackId, "message" => message = %{ "data" => data, "messageId" => messageId, "publishTime" => publishTime}} <- messages do
              case message do
                %{"attributes" => %{"topic" => topic}} ->
                  payload = Base.decode64!(data)
                  amqp_topic = String.replace(topic, "/", ".")
                  ampq_exchange = Application.get_env(:amqp_pubsub, :ampq_exchange)
                  case Basic.publish chan, ampq_exchange, amqp_topic, payload do
                    :ok -> ackId
                    err_ret -> Logger.debug "Error forwarding to rabbitmq: #{inspect err_ret}"
                               nil
                  end
                  ackId  # ack all Pubsub messages for now
                _ ->
                  Logger.debug "No topic in attributes!"
                  ackId
              end
            end |> Enum.filter(&(not is_nil(&1)))
          _ ->
            # no messsages to pull
            []
        end
      {:error, resp} -> Logger.debug "Some error pulling messages...\n#{inspect resp}"
                        []
    end

    if not Enum.empty? acks do
      ackBody = %{"ackIds" => acks}
      ackResp = Pubsub.ack_subscription(Application.get_env(:amqp_pubsub, :reverse_subscription), ackBody)
    end

    schedule_work()
  end

  defp schedule_work(delay \\ 1_000) do
    Process.send_after(self(), :work, delay)
  end

end
