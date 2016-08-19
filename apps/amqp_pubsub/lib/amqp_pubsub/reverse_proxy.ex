defmodule AmqpPubsub.ReverseProxy do
  require Logger
  use GenServer
  use AMQP
  alias AmqpPubsub.Google.Pubsub


  @subscription_name "rabbitmq-proxy"
  @subscription_topic_name "to-gateway"


  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(_opts) do
    conn_options = Application.get_env(:amqp_pubsub, :ampq_conn_options)

    Logger.info "ampq conn options: #{inspect conn_options}"
    {:ok, conn} =  AMQP.Connection.open conn_options
    {:ok, chan} = Channel.open(conn)
    Basic.qos(chan, prefetch_count: 10)

    Pubsub.create_cloud_pubsub_topic(@subscription_topic_name)
    Pubsub.create_subscription(@subscription_name, @subscription_topic_name)

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
    acks = case Pubsub.pull_subscription(@subscription_name, body, recv_timeout: :infinity) do
      {:ok, resp} ->
        IO.puts "pulled pubsub!"
        Logger.debug "#{inspect resp}"
        case (resp.body |> Poison.decode!)["receivedMessages"] do
          messages when is_list(messages) ->
            for receivedMessage = %{"ackId" => ackId, "message" => message = %{ "data" => data, "messageId" => messageId, "publishTime" => publishTime}} <- messages do
              case message do
                %{"attributes" => %{"topic" => topic}} ->
                  IO.puts "Each message: #{inspect receivedMessage}"
                  payload = Base.decode64!(data)
                  IO.puts "topic: #{topic}"
                  IO.puts "payload: #{payload}"
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
            IO.puts "no messages to pull!"
            []
        end
      {:error, resp} -> IO.puts "Some error pulling...\n#{inspect resp}"
                        []
    end

    Logger.debug "number of acks: #{Enum.count(acks)}"
    Logger.debug "ackIds: #{inspect acks}"
    if not Enum.empty? acks do
      ackBody = %{"ackIds" => acks}
      ackResp = Pubsub.ack_subscription(@subscription_name, ackBody)
      IO.puts "ackResp: #{inspect ackResp}"
    end

    schedule_work()
  end

  defp schedule_work(delay \\ 1_000) do
    Process.send_after(self(), :work, delay)
  end

end
