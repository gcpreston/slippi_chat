defmodule SlippiChatWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use SlippiChatWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint SlippiChatWeb.Endpoint

      use SlippiChatWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import SlippiChat.TimeHelper
      import SlippiChatWeb.ConnCase
    end
  end

  setup tags do
    SlippiChat.DataCase.setup_sandbox(tags)
    SlippiChat.Injections.set_chat_session_registry(tags.test)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Wait for a LiveView html-based assertion to pass.

  Accepts a LiveView from Phoenix.LiveViewTest.live/2, and a function
  of arity 1, which gets passed html from the rendered LiveView.
  Returns the rendered html which passed the assertion.

  ## Examples

      iex> {:ok, lv, _html} = live(conn, ~p"/rooms/4")
      iex> html = render_until(lv, fn html -> assert html =~ "Loading finished!" end)
  """
  def render_until(lv, fun) do
    wrapped_fun = fn ->
      html = Phoenix.LiveViewTest.render(lv)
      fun.(html)
      html
    end

    SlippiChat.TimeHelper.wait_until(wrapped_fun)
  end

  @doc """
  Logs a user for the given `client_code` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, client_code) do
    token = SlippiChat.Auth.generate_user_session_token(client_code)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
