defmodule SlippiChatWeb.CreateTokenLive do
  use SlippiChatWeb, :live_view

  alias SlippiChat.Auth

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md">
      <.simple_form for={@form} id="grant-form" phx-submit="create" phx-update="ignore">
        <.input field={@form[:grantee]} label="Connect code" required />

        <:actions>
          <.button phx-disable-with="Creating..." class="w-full">
            Create token
          </.button>
        </:actions>
      </.simple_form>

      <div :if={@new_token} class="mt-4 text-center">
        <div class="text-zinc-600">New token created, copy it now, you won't be able to again:</div>
        <div id="new-token">{@new_token}</div>
        <span>
          <.button
            onclick="copyToClipboard()"
            class="mt-2 display-block"
            phx-click={JS.remove_class("hidden", to: "#check")}
          >
            Copy
          </.button>
          <span id="check" class="hidden"><.icon name="hero-check-solid" /></span>
        </span>
      </div>

      <script>
        function copyToClipboard() {
          const copyTextElem = document.getElementById("new-token");
          navigator.clipboard.writeText(copyTextElem.innerHTML);
        }
      </script>
    </div>
    """
  end

  def handle_event("create", %{"grantee" => grantee}, socket) do
    socket =
      case Auth.register_user(%{connect_code: grantee, is_admin: false}) do
        {:ok, _new_user, new_token} ->
          assign(socket, new_token: new_token)

        {:error, _} ->
          put_flash(socket, :error, "Failed to create token, does this user already exist?")
      end

    {:noreply, socket}
  end

  def mount(_params, _session, socket) do
    form = to_form(%{"grantee" => nil})

    {:ok,
     socket
     |> assign(form: form)
     |> assign(new_token: nil), temporary_assigns: [form: form]}
  end
end
