defmodule SlippiChat.PlayerRegistryTest do
  use ExUnit.Case, async: true

  alias SlippiChat.PlayerRegistry

  setup do
    pid = start_supervised!({PlayerRegistry, name: TestPlayerRegistry})
    %{pid: pid}
  end

  describe "add/1" do
    test "adds a player code to the registry", %{pid: pid} do
      assert MapSet.equal?(PlayerRegistry.list(pid), MapSet.new())

      assert :ok = PlayerRegistry.add(pid, "WAFF#715")
      assert MapSet.equal?(PlayerRegistry.list(pid), MapSet.new(["WAFF#715"]))

      assert :ok = PlayerRegistry.add(pid, "MANG#0")
      assert MapSet.equal?(PlayerRegistry.list(pid), MapSet.new(["WAFF#715", "MANG#0"]))

      assert :ok = PlayerRegistry.add(pid, "WAFF#715")
      assert MapSet.equal?(PlayerRegistry.list(pid), MapSet.new(["WAFF#715", "MANG#0"]))
    end
  end

  describe "remove/1" do
    test "removes a player code from the registry", %{pid: pid} do
      PlayerRegistry.add(pid, "WAFF#715")
      assert MapSet.equal?(PlayerRegistry.list(pid), MapSet.new(["WAFF#715"]))

      assert :ok = PlayerRegistry.remove(pid, "MANG#0")
      assert MapSet.equal?(PlayerRegistry.list(pid), MapSet.new(["WAFF#715"]))

      assert :ok = PlayerRegistry.remove(pid, "WAFF#715")
      assert MapSet.equal?(PlayerRegistry.list(pid), MapSet.new())
    end
  end
end
