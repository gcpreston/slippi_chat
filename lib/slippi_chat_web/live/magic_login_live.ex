defmodule SlippiChatWeb.MagicLoginLive do
  use SlippiChatWeb, :live_view
  require Logger

  alias SlippiChat.Auth
  alias SlippiChat.Auth.MagicAuthenticator

  defp magic_authenticator do
    Application.fetch_env!(:slippi_chat, :magic_authenticator)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Magic login
      </.header>

      <div class="text-center mt-12">
        <div>Your magic code is</div>
        <div class="mt-6 text-6xl">
          {@verification_code}
        </div>
      </div>

      <.simple_form
        id="redirect_form"
        class="hidden"
        for={@form}
        action={~p"/log_in"}
        phx-trigger-action={@trigger_submit}
      >
        <.input type="text" field={@form[:login_token]} />

        <:actions>
          <.button type="submit">Submit</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(%{"t" => magic_token}, _session, socket) do
    if client_code = Auth.get_user_by_magic_token(magic_token) do
      verification_code =
        if connected?(socket) do
          MagicAuthenticator.register_verification_code(magic_authenticator(), client_code)
        else
          nil
        end

      form = to_form(%{"login_token" => nil})

      {:ok,
       socket
       |> assign(:client_code, client_code)
       |> assign(:verification_code, verification_code)
       |> assign(:form, form)
       |> assign(:trigger_submit, false), temporary_assigns: [form: form]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Invalid magic token")
       |> redirect(to: ~p"/log_in")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: ~p"/log_in")}
  end

  @impl true
  def handle_info({:verified, %{login_token: login_token}}, socket) do
    {:noreply,
     assign(socket, form: to_form(%{"login_token" => login_token}), trigger_submit: true)}
  end

  def handle_info(message, socket) do
    Logger.debug("MagicLoginLive - unhandled message: #{inspect(message)}")
    {:noreply, socket}
  end
end
