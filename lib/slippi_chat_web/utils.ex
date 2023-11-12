defmodule SlippiChatWeb.Utils do
  @doc """
  Translate a game player code to an HTML and URL-safe version.

  ## Examples

      iex> safe_player_code("ABC#123")
      "abc-123"
  """
  def safe_player_code(game_player_code) do
    String.replace(game_player_code, "#", "-")
    |> String.downcase()
  end

  @doc """
  Translate a safe player code to the version found in Slippi.

  ## Examples

      iex> game_player_code("abc-123")
      "ABC#123"
  """
  def game_player_code(safe_player_code) do
    String.replace(safe_player_code, "-", "#")
    |> String.upcase()
  end
end
