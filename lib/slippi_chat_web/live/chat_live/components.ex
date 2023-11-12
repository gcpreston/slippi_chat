defmodule SlippiChatWeb.ChatLive.Components do
  @moduledoc """
  Function components specific to the /chat LiveView.
  """
  use Phoenix.Component

  attr :online, :boolean, default: false
  attr :class, :string, default: nil

  def status_icon(assigns) do
    assigns =
      assign(
        assigns,
        :circle_attrs,
        if assigns[:online] do
          %{stroke: "#16a34a", "stroke-width": "2", fill: "#16a34a"}
        else
          %{stroke: "#a3a3a3", "stroke-width": "2", fill: "#f5f5f5"}
        end
      )

    ~H"""
    <svg viewBox="0 0 15 15" height="10" class={["inline", @class]}>
      <circle cx="50%" cy="50%" r="6" {@circle_attrs} />
    </svg>
    """
  end
end
