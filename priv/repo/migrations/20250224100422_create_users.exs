defmodule SlippiChat.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :connect_code, :string, size: 16, null: false
      add :is_admin, :boolean, null: false, default: false

      timestamps()
    end
  end
end
