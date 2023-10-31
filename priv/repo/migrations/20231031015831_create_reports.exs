defmodule SlippiChat.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :reporter, :string, size: 16, null: false
      add :reportee, :string, size: 16, null: false
      add :chat_log, :map, null: false

      timestamps(updated_at: false)
    end
  end
end
