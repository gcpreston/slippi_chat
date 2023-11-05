defmodule SlippiChatWeb.UserLoginLive do
  use SlippiChatWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md">
      <.header class="text-center">
        SlippiChat

        <:subtitle>
          Text chat for Slippi netplay. <a href="https://github.com/gcpreston/slippi_chat" target="_blank" class="text-blue-600 hover:underline">Check it out on GitHub :)</a>
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/log_in"} phx-update="ignore">
        <.input field={@form[:client_token]} type="password" label="Client token" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
        </:actions>
        <:actions>
          <.button phx-disable-with="Signing in..." class="w-full">
            Sign in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>

      <ul class="mt-6 text-zinc-800 ">
        <li>
          <.icon name="hero-arrow-down-circle" class="mr-2" />Download the client <a
            href="https://github.com/gcpreston/slippi-chat-client/releases"
            target="_blank"
            class="text-blue-600 hover:underline"
          >here</a>.
        </li>
        <li>
          <.icon name="hero-question-mark-circle" class="mr-2" />Need a token? Message graham#4664 on Discord.
        </li>
      </ul>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    form = to_form(%{"client_token" => nil})
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
