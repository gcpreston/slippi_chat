defmodule SlippiChatWeb.MagicLoginJSON do
  def show(%{magic_token: magic_token}) do
    %{data: %{magic_token: magic_token}}
  end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
