defmodule ElevatorsWeb.Components.Elevator do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    Elevators.Pubsub.Client.start()
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>Boom</div>
    """
  end

  def handle_info(:progress, socket) do
    {:noreply, socket}
  end

  defp floors(), do: Enum.to_list(-4..5)
end
