defmodule SlippiChatWeb.ChatLive.Message.Form do
  use SlippiChatWeb, :live_component

  import SlippiChatWeb.CoreComponents

  alias SlippiChat.ChatSessions.{ChatSession, Message}

  def update(assigns, socket) do
    changeset = change_message(%{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        as={:message}
        phx-submit="save"
        phx-change="update"
        phx-target={@myself}
      >
        <.input type="text" autocomplete="off" field={@form[:content]} />
        <:actions>
          <.button>Send</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def handle_event("update", params, socket) do
    {:noreply, socket |> assign_form(change_message(params))}
  end

  def handle_event("save", %{"message" => %{"content" => content}}, socket) do
    message = Message.new(content, socket.assigns.sender)
    ChatSession.send_message(socket.assigns.chat_session_pid, message)
    empty_changeset = change_message(%{})

    {:noreply, socket |> assign_form(empty_changeset)}
  end

  defp change_message(params) do
    data = %{}
    types = %{content: :string, sender: :string}

    {data, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :message))
  end
end
