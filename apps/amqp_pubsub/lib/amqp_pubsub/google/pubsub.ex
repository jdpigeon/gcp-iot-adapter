defmodule AmqpPubsub.Google.Pubsub do
  require Logger
  alias GoogleApi.V1.Pubsub.Projects.Topics
  alias GoogleApi.V1.Pubsub.Projects.Subscriptions

  @google_api_executor OauthJwt.Client
  @google_api_executor_pid OauthJwt.Client

  def publish(topic, body) do
    full_topic = get_full_pubsub_topic(topic)
    response = Topics.publish(@google_api_executor, @google_api_executor_pid, topic: full_topic, body: body)
  end

  def create_cloud_pubsub_topic(name) do
    full_pubsub_topic = get_full_pubsub_topic(name)
    Logger.debug "Get or create cloud pubsub topic: #{full_pubsub_topic}"
    case Topics.get(@google_api_executor, @google_api_executor_pid, topic: full_pubsub_topic) do
      {:ok, resp = %{status_code: 404}} -> Logger.debug "topic not found, creating it!"
                        Logger.debug "#{inspect resp}"
                        create_resp = Topics.create(@google_api_executor, @google_api_executor_pid, name: full_pubsub_topic)
                        Logger.debug "Topic create response:"
                        Logger.debug "#{inspect create_resp}"
      {:ok, resp} -> Logger.debug "Topic was found: #{full_pubsub_topic}"
                     Logger.debug "Response: #{inspect resp}"
    end
  end

  def get_full_pubsub_topic(topic) do
    get_full_pubsub_topic topic, Application.get_env(:amqp_pubsub, :pubsub_project_prefix)
  end

  def get_full_pubsub_topic(topic, prefix) do
    "#{prefix}topics/#{topic}"
  end

  def get_full_pubsub_subscription(subscription) do
    get_full_pubsub_subscription subscription, Application.get_env(:amqp_pubsub, :pubsub_project_prefix)
  end

  def get_full_pubsub_subscription(subscription, prefix) do
    "#{prefix}subscriptions/#{subscription}"
  end

  def assemble_pubsub_message(payload, nil) do
    data = encode_payload(payload)
    %{"data" => data}
  end

  def assemble_pubsub_message(payload, attributes = %{}) do
    data = encode_payload(payload)
    %{"data" => data, "attributes" => attributes}
  end

  def encode_payload(payload) do
    Base.encode64(payload)
  end

  def get_subscription(subscription) do
    Subscriptions.get(@google_api_executor, @google_api_executor_pid, subscription: subscription)
  end

  def create_subscription(subscription_name, subscription_topic_name) do
    full_subscription_name = get_full_pubsub_subscription(subscription_name)
    full_subscription_topic_path = get_full_pubsub_topic(subscription_topic_name)
    Logger.debug "Trying to create subscription #{full_subscription_name}"
    case get_subscription(full_subscription_name) do
      {:ok, resp = %{status_code: 404}} ->
        Logger.debug "Creating subscription #{full_subscription_name}"
        body = %{
          "topic" => full_subscription_topic_path,
          "ackDeadlineSeconds": 30,
        }
        resp2 = Subscriptions.create(@google_api_executor, @google_api_executor_pid, name: full_subscription_name, body: body)
        Logger.debug "#{inspect resp2}"

      {:ok, resp} ->
        Logger.debug "Found subscription: #{inspect resp}"
    end

  end

  def pull_subscription(subscription, body, options \\ []) do
    full_subscription_name = get_full_pubsub_subscription(subscription)

    params = Keyword.merge([subscription: full_subscription_name, body: body], options)
    Subscriptions.pull(@google_api_executor, @google_api_executor_pid, params)
  end

  def ack_subscription(subscription, body) do
    full_subscription_name = get_full_pubsub_subscription(subscription)
    Subscriptions.acknowledge(@google_api_executor, @google_api_executor_pid, subscription: full_subscription_name, body: body)
  end

  def get_topic(topic) do
    Topics.get(@google_api_executor, @google_api_executor_pid, topic: topic)
  end

end
