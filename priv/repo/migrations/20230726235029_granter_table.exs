defmodule SlippiChat.Repo.Migrations.GranterTable do
  use Ecto.Migration

  def change do
    create table(:token_granters) do
      add :client_token_id, references(:clients_tokens, on_delete: :delete_all), null: false
      add :granter_code, :string, null: false
      timestamps(updated_at: false)
    end

    alter table(:clients_tokens) do
      remove :granter_code
      remove :granter_token
    end
  end
end
