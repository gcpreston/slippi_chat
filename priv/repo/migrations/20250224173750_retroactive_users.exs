defmodule SlippiChat.Repo.Migrations.RetroactiveUsers do
  use Ecto.Migration
  import Ecto.Query

  alias SlippiChat.Repo
  alias SlippiChat.Auth.User

  def change do
    clients_query =
      from t in SlippiChat.Auth.ClientToken,
        where: t.context == "client",
        select: t.client_code

    client_connect_codes = SlippiChat.Repo.all(clients_query)

    Repo.transaction(fn ->
      for connect_code <- client_connect_codes do
        is_admin = connect_code == "WAFF#715"

        %User{connect_code: connect_code, is_admin: is_admin}
        |> Repo.insert!()
      end
    end)
  end
end
