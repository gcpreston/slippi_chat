defmodule SlippiChat.SlippiAuthBridge.AuthSocket do
  use WebSockex

  alias SlippiChat.Events
  require Logger

  @topic inspect(__MODULE__)

  ## API

  def start_link(opts) do
    {url, opts} = Keyword.pop!(opts, :url)
    {state, opts} = Keyword.pop(opts, :state)
    state = state || %{}

    WebSockex.start_link(url, __MODULE__, state, opts)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(SlippiChat.PubSub, @topic)
  end

  def queue(client, connect_code, timeout) do
    data = %{type: "queue", code: connect_code, timeout: timeout}
    WebSockex.cast(client, {:text, Jason.encode!(data)})
  end

  ## Callbacks

  def handle_connect(conn, state) do
    Logger.info("AuthSocket connected to ws://#{conn.host}:#{conn.port}")
    {:ok, state}
  end

  # TODO: Application shuts down on disconnect
  def handle_disconnect(connection_status_map, state) do
    Logger.info("AuthSocket disconnected: #{inspect(connection_status_map)}")
    {:ok, state}
  end

  def handle_frame({type, msg}, state) do
    data =
      case Jason.decode(msg) do
        {:ok, data} ->
          Logger.info("Received JSON data: #{inspect(data)}")
          data

        _ ->
          IO.puts("Received Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}")
          nil
      end

    case data do
      %{type: "success", code: connect_code} ->
        Logger.info("Player #{connect_code} has been verified")

      other ->
        Logger.warning("Received error: #{inspect(other)}")
    end

    {:ok, state}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts("Sending #{type} frame with payload: #{msg}")
    {:reply, frame, state}
  end

  ## Helpers

  defp notify_subscribers(:verified, connect_code) do
    event = %Events.UserVerified{connect_code: connect_code}

    Phoenix.PubSub.broadcast(
      SlippiChat.PubSub,
      @topic,
      {__MODULE__, event}
    )
  end
end
