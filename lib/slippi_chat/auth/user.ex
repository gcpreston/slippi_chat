defmodule SlippiChat.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :connect_code, :string
    field :is_admin, :boolean

    timestamps()
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:connect_code, :is_admin])
    |> validate_connect_code()
  end

  defp validate_connect_code(changeset) do
    changeset
    |> validate_required([:connect_code])
    |> validate_format(:connect_code, ~r/^[A-Z]+#[[:digit:]]+$/,
      message: "must be in the format ABC#123"
    )
    |> validate_length(:connect_code, max: 16)
    |> unsafe_validate_unique(:connect_code, SlippiChat.Repo)
    |> unique_constraint(:connect_code)
  end
end
