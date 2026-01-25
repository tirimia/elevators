defmodule ElevatorsWeb.Live.Main do
  use ElevatorsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Elevators.PubSub, "elevator:arrived")
      Phoenix.PubSub.subscribe(Elevators.PubSub, "floor:call")

      # Subscribe to each elevator's movement
      for elevator_id <- get_elevator_ids() do
        Phoenix.PubSub.subscribe(Elevators.PubSub, "elevator:#{elevator_id}")
      end
    end

    {:ok,
     assign(socket,
       floors: get_floors(),
       elevator_ids: Enum.to_list(get_elevator_ids()),
       floor_states: get_floor_states()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-primary">
      <div class="max-w-7xl mx-auto px-8 py-12">
        <h1 class="text-5xl font-bold mb-12 text-center text-base-content">Elevator System</h1>

        <div class="flex gap-12 justify-center items-start overflow-x-auto">
          <!-- Floor buttons column -->
          <div class="flex flex-col-reverse gap-3">
            <div class="font-bold text-lg mb-3 text-center text-base-content">Floors</div>
            <div :for={floor <- @floors} class="h-24 flex items-center justify-end gap-3">
              <div class="font-mono text-2xl w-16 text-right font-bold text-base-content">
                {floor}
              </div>
              <div class="flex flex-row gap-1 items-center justify-center w-20">
                <%= if floor < Enum.max(@floors) do %>
                  <button
                    phx-click="call_up"
                    phx-value-floor={floor}
                    class={[
                      "btn btn-xs transition-all w-8 h-8 bg-neutral hover:bg-neutral-focus shadow-md",
                      (floor_wants_up?(@floor_states, floor) && "text-primary") ||
                        "text-neutral-content"
                    ]}
                  >
                    ▲
                  </button>
                <% end %>
                <%= if floor > Enum.min(@floors) do %>
                  <button
                    phx-click="call_down"
                    phx-value-floor={floor}
                    class={[
                      "btn btn-xs transition-all w-8 h-8 bg-neutral hover:bg-neutral-focus shadow-md",
                      (floor_wants_down?(@floor_states, floor) && "text-primary") ||
                        "text-neutral-content"
                    ]}
                  >
                    ▼
                  </button>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Elevators columns -->
          <.live_component
            :for={elevator_id <- @elevator_ids}
            module={ElevatorsWeb.Live.ElevatorComponent}
            id={"elevator-#{elevator_id}"}
            elevator_id={elevator_id}
            floors={@floors}
            control_unit={get_elevator_state(elevator_id)}
          />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("call_up", %{"floor" => floor_str}, socket) do
    floor = String.to_integer(floor_str)
    Elevators.Floor.press_up_button(floor)
    {:noreply, socket}
  end

  @impl true
  def handle_event("call_down", %{"floor" => floor_str}, socket) do
    floor = String.to_integer(floor_str)
    Elevators.Floor.press_down_button(floor)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{
          event: :moving,
          elevator_id: id,
          floor: floor,
          direction: direction,
          internal_queue: queue,
          external_calls: calls
        },
        socket
      ) do
    # Send update to specific elevator component
    send_update(ElevatorsWeb.Live.ElevatorComponent,
      id: "elevator-#{id}",
      control_unit: %{
        floor: floor,
        state: direction,
        doors_open: false,
        internal_queue: queue,
        external_calls: calls
      }
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: :floor_selected, elevator_id: id, internal_queue: queue}, socket) do
    # Send update to specific elevator component
    control_unit = get_elevator_state(id)

    if control_unit do
      send_update(ElevatorsWeb.Live.ElevatorComponent,
        id: "elevator-#{id}",
        control_unit: %{control_unit | internal_queue: queue}
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{
          event: :arrived,
          elevator_id: id,
          floor: floor,
          direction: direction,
          internal_queue: queue,
          external_calls: calls
        },
        socket
      ) do
    # Send update to specific elevator component
    send_update(ElevatorsWeb.Live.ElevatorComponent,
      id: "elevator-#{id}",
      control_unit: %{
        floor: floor,
        state: direction,
        doors_open: true,
        internal_queue: queue,
        external_calls: calls
      }
    )

    # Clear the floor button state for the serviced direction
    {:noreply,
     update(socket, :floor_states, fn floor_states ->
       update_in(floor_states, [floor], fn current_state ->
         case direction do
           :going_up -> %{current_state | wants_up: false}
           :going_down -> %{current_state | wants_down: false}
         end
       end)
     end)}
  end

  @impl true
  def handle_info(%{floor: floor_num, direction: direction}, socket) do
    # Floor button pressed - update specific floor state
    {:noreply,
     update(socket, :floor_states, fn floor_states ->
       update_in(floor_states, [floor_num], fn current_state ->
         case direction do
           :going_up -> %{current_state | wants_up: true}
           :going_down -> %{current_state | wants_down: true}
         end
       end)
     end)}
  end

  defp get_floors do
    config = Application.fetch_env!(:elevators, Elevators.System)
    lowest = Keyword.fetch!(config, :lowest_floor)
    highest = Keyword.fetch!(config, :highest_floor)
    Enum.to_list(lowest..highest)
  end

  defp get_elevator_ids do
    config = Application.fetch_env!(:elevators, Elevators.System)
    num_elevators = Keyword.fetch!(config, :num_elevators)
    1..num_elevators
  end

  defp get_elevator_state(elevator_id) do
    case Registry.lookup(Elevators.Registry, {:elevator, elevator_id}) do
      [{pid, _}] ->
        state = GenServer.call(pid, :get_state)
        state.control_unit

      [] ->
        nil
    end
  end

  defp get_floor_states do
    floors = get_floors()

    for floor <- floors, into: %{} do
      {floor,
       %{
         wants_up: Elevators.Floor.wants_up?(floor),
         wants_down: Elevators.Floor.wants_down?(floor)
       }}
    end
  end

  defp floor_wants_up?(floor_states, floor) do
    floor_states[floor][:wants_up] || false
  end

  defp floor_wants_down?(floor_states, floor) do
    floor_states[floor][:wants_down] || false
  end
end
