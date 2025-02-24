defmodule SlippiChat.AuthFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `SlippiChat.Auth` context.
  """
  alias SlippiChat.Repo
  alias SlippiChat.Auth.User
  import Ecto.Query

  defp random_connect_code do
    letters = for _ <- 1..4, into: "", do: <<Enum.random(?A..?Z)>>
    number = :rand.uniform(1000) - 1
    "#{letters}##{number}"
  end

  defp unique_connect_code do
    generated_connect_code = random_connect_code()

    if Repo.exists?(from u in User, where: u.connect_code == ^generated_connect_code) do
      unique_connect_code()
    else
      generated_connect_code
    end
  end

  def valid_user_attributes(attrs \\ %{}) do
    connect_code = unique_connect_code()

    Enum.into(attrs, %{
      connect_code: connect_code,
      is_admin: false
    })
  end

  def user_fixture(attrs \\ %{}) do
    valid_attrs = valid_user_attributes(attrs)
    {:ok, user, _token} = SlippiChat.Auth.register_user(valid_attrs)
    user
  end
end
