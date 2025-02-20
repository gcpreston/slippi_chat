defmodule SlippiChatWeb.CreateTokenLive do
  use SlippiChatWeb, :live_view

  def render(assigns) do
    ~H"""
    Create token placeholder: <%= @current_user_code %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
