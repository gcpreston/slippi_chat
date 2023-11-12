defmodule SlippiChatWeb.UtilsTest do
  use ExUnit.Case, async: true

  alias SlippiChatWeb.Utils

  describe "safe_player_code/1" do
    test "translates a player code" do
      assert Utils.safe_player_code("IDK#444") == "idk-444"
    end
  end

  describe "game_player_code/1" do
    test "de-translates a player code" do
      assert Utils.game_player_code("idk-444") == "IDK#444"
    end
  end
end
