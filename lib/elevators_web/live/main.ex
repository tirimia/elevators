defmodule ElevatorsWeb.Live.Main do
  use ElevatorsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Elevators.PubSub, "elevator:arrived")
      Phoenix.PubSub.subscribe(Elevators.PubSub, "floor:call")

      # Subscribe to each elevator's movement
      for elevator_id <- 1..3 do
        Phoenix.PubSub.subscribe(Elevators.PubSub, "elevator:#{elevator_id}")
      end
    end

    {:ok,
     assign(socket,
       floors: get_floors(),
       elevators: get_elevator_states(),
       floor_states: get_floor_states()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-8 py-12">
      <h1 class="text-5xl font-bold mb-12 text-center">Elevator System</h1>

      <div class="flex gap-12 justify-center">
        <!-- Floor buttons column -->
        <div class="flex flex-col-reverse gap-3">
          <div class="font-bold text-lg mb-3 text-center">Floors</div>
          <div :for={floor <- @floors} class="flex items-center gap-3 h-24">
            <div class="font-mono text-lg w-12 text-right font-semibold">{floor}</div>
            <div class="flex flex-col gap-2">
              <%= if floor < Enum.max(@floors) do %>
                <button
                  phx-click="call_up"
                  phx-value-floor={floor}
                  class={[
                    "px-3 py-2 text-sm rounded font-semibold transition-colors",
                    (floor_wants_up?(@floor_states, floor) && "bg-green-500 text-white shadow-md") ||
                      "bg-gray-200 hover:bg-gray-300"
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
                    "px-3 py-2 text-sm rounded font-semibold transition-colors",
                    (floor_wants_down?(@floor_states, floor) && "bg-green-500 text-white shadow-md") ||
                      "bg-gray-200 hover:bg-gray-300"
                  ]}
                >
                  ▼
                </button>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Elevators columns -->
        <div :for={elevator_id <- 1..3} class="flex flex-col-reverse gap-3">
          <div class="font-bold text-lg mb-3 text-center">Elevator {elevator_id}</div>
          <div :for={floor <- @floors} class="h-24 flex items-center justify-center">
            <div class={[
              "w-32 h-20 border-4 rounded-lg flex items-center justify-center font-mono text-xl transition-all",
              (elevator_at_floor?(@elevators, elevator_id, floor) &&
                 elevator_doors_open?(@elevators, elevator_id) &&
                 "bg-green-100 border-green-500 shadow-lg") ||
                (elevator_at_floor?(@elevators, elevator_id, floor) &&
                   "bg-blue-100 border-blue-500 shadow-lg") ||
                "border-gray-300 bg-gray-50"
            ]}>
              <%= if elevator_at_floor?(@elevators, elevator_id, floor) do %>
                <span class="text-3xl">{elevator_direction_arrow(@elevators, elevator_id)}</span>
              <% end %>
            </div>
          </div>
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
  def handle_info(_msg, socket) do
    # Refresh state on any elevator or floor event
    {:noreply,
     assign(socket,
       elevators: get_elevator_states(),
       floor_states: get_floor_states()
     )}
  end

  defp get_floors do
    config = Application.fetch_env!(:elevators, Elevators.System)
    lowest = Keyword.fetch!(config, :lowest_floor)
    highest = Keyword.fetch!(config, :highest_floor)
    Enum.to_list(lowest..highest)
  end

  defp get_elevator_states do
    for elevator_id <- 1..3, into: %{} do
      case Registry.lookup(Elevators.Registry, {:elevator, elevator_id}) do
        [{pid, _}] ->
          state = GenServer.call(pid, :get_state)
          {elevator_id, state.control_unit}

        [] ->
          {elevator_id, nil}
      end
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

  defp elevator_at_floor?(elevators, elevator_id, floor) do
    case elevators[elevator_id] do
      nil -> false
      control_unit -> control_unit.floor == floor
    end
  end

  defp elevator_doors_open?(elevators, elevator_id) do
    case elevators[elevator_id] do
      nil -> false
      control_unit -> control_unit.doors_open
    end
  end

  defp elevator_direction_arrow(elevators, elevator_id) do
    case elevators[elevator_id] do
      nil ->
        ""

      control_unit ->
        case control_unit.state do
          :going_up -> "↑"
          :going_down -> "↓"
        end
    end
  end

  defp floor_wants_up?(floor_states, floor) do
    floor_states[floor][:wants_up] || false
  end

  defp floor_wants_down?(floor_states, floor) do
    floor_states[floor][:wants_down] || false
  end
end
