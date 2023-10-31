defmodule SlippiChat.ChatSessions do
  alias SlippiChat.Repo
  alias SlippiChat.ChatSessions.Report

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

  @spec create_report!(String.t(), String.t(), list(SlippiChat.ChatSessions.Message.t())) ::
          Report.t()
  def create_report!(reporter, reportee, chat_log) do
    report = %Report{reporter: reporter, reportee: reportee, chat_log: chat_log}
    Repo.insert!(report)
  end
end
