defmodule SlippiChat.Repo.Migrations.CreateAccessTokens do
  use Ecto.Migration

  def change do
    create table(:clients_tokens) do
      add :client_code, :string, null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :granter_code, :string, null: true
      add :granter_token, :binary, null: true
      timestamps(updated_at: false)
    end

    create index(:clients_tokens, [:token])
    create unique_index(:clients_tokens, [:context, :token])
  end
end
