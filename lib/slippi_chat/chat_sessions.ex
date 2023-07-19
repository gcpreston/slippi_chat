defmodule SlippiChat.ChatSessions do
  @pubsub_topic "chat_sessions"

  def player_topic(player_code) when is_binary(player_code) do
    "#{@pubsub_topic}:#{String.upcase(player_code)}"
  end

  def chat_session_topic(player_codes) when is_list(player_codes) do
    suffix =
      Enum.map(player_codes, &String.upcase/1)
      |> Enum.sort()
      |> Enum.join(",")

    "#{@pubsub_topic}:#{suffix}"
  end
end
