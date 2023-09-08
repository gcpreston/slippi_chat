defmodule SlippiChatWeb.PageController do
  use SlippiChatWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/chat")
  end
end
