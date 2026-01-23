defmodule ElevatorsWeb.Live.Main do
  use ElevatorsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div>
        <.live_component module={ElevatorsWeb.Components.Elevator} id={"elevator-#{elevator}"} :for={elevator <- [1,2]} />
      </div>
    </Layouts.app>
    """
  end
      #<button class="btn btn-accent">Haaa</button>
end
