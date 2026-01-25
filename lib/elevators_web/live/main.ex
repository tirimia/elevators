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
       elevators: get_elevator_states(),
       floor_states: get_floor_states()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-8 py-12">
      <h1 class="text-5xl font-bold mb-12 text-center">Elevator System</h1>

      <div class="flex flex-wrap gap-12 justify-center">
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
        <div :for={elevator_id <- get_elevator_ids()} class="flex gap-6">
          <div class="flex flex-col-reverse gap-3">
            <div class="font-bold text-lg mb-3 text-center">Elevator {elevator_id}</div>
            <div :for={floor <- @floors} class="h-24 flex items-center justify-center">
              <div class={[
                "w-32 h-20 border-4 rounded-lg relative overflow-hidden transition-all",
                (elevator_at_floor?(@elevators, elevator_id, floor) &&
                   "border-blue-500 shadow-lg") ||
                  "border-gray-300"
              ]}>
                <%= if elevator_at_floor?(@elevators, elevator_id, floor) do %>
                  <!-- Elevator interior background -->
                  <div class="absolute inset-0 bg-blue-50 flex items-center justify-center">
                    <span class="text-3xl z-10">
                      {elevator_direction_arrow(@elevators, elevator_id)}
                    </span>
                  </div>
                  
    <!-- Left door -->
                  <div class={[
                    "absolute top-0 bottom-0 left-0 bg-gradient-to-r from-gray-700 to-gray-600 border-r-2 border-gray-500 transition-all duration-700 ease-in-out",
                    (elevator_doors_open?(@elevators, elevator_id) && "w-0") || "w-1/2"
                  ]}>
                  </div>
                  
    <!-- Right door -->
                  <div class={[
                    "absolute top-0 bottom-0 right-0 bg-gradient-to-l from-gray-700 to-gray-600 border-l-2 border-gray-500 transition-all duration-700 ease-in-out",
                    (elevator_doors_open?(@elevators, elevator_id) && "w-0") || "w-1/2"
                  ]}>
                  </div>
                <% else %>
                  <!-- Empty shaft -->
                  <div class="absolute inset-0 bg-gray-50"></div>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Control Panel -->
          <div class="flex flex-col gap-3">
            <div class="font-bold text-lg mb-3 text-center">Panel</div>
            <div class="bg-gray-800 p-4 rounded-lg shadow-lg">
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                <button
                  :for={floor <- Enum.reverse(@floors)}
                  phx-click="select_floor"
                  phx-value-elevator={elevator_id}
                  phx-value-floor={floor}
                  class={[
                    "w-full aspect-square rounded font-mono font-bold text-sm transition-all flex items-center justify-center",
                    (elevator_has_floor_selected?(@elevators, elevator_id, floor) &&
                       "bg-yellow-400 text-gray-900 shadow-md ring-2 ring-yellow-300") ||
                      "bg-gray-700 text-gray-300 hover:bg-gray-600"
                  ]}
                >
                  {floor}
                </button>
              </div>
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
  def handle_event("select_floor", %{"elevator" => elevator_id_str, "floor" => floor_str}, socket) do
    elevator_id = String.to_integer(elevator_id_str)
    floor = String.to_integer(floor_str)
    Elevators.Elevator.select_floor(elevator_id, floor)
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
    # Update only the specific elevator that moved
    {:noreply,
     update(socket, :elevators, fn elevators ->
       case elevators[id] do
         nil ->
           elevators

         control_unit ->
           updated = %{
             control_unit
             | floor: floor,
               state: direction,
               doors_open: false,
               internal_queue: queue,
               external_calls: calls
           }

           Map.put(elevators, id, updated)
       end
     end)}
  end

  @impl true
  def handle_info(%{event: :floor_selected, elevator_id: id, internal_queue: queue}, socket) do
    # Update only the specific elevator's internal queue
    {:noreply,
     update(socket, :elevators, fn elevators ->
       case elevators[id] do
         nil ->
           elevators

         control_unit ->
           updated = %{control_unit | internal_queue: queue}
           Map.put(elevators, id, updated)
       end
     end)}
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
    # Update elevator to show doors open at arrival floor
    # Also clear the floor button state for the serviced direction
    {:noreply,
     socket
     |> update(:elevators, fn elevators ->
       case elevators[id] do
         nil ->
           elevators

         control_unit ->
           updated = %{
             control_unit
             | floor: floor,
               doors_open: true,
               internal_queue: queue,
               external_calls: calls
           }

           Map.put(elevators, id, updated)
       end
     end)
     |> update(:floor_states, fn floor_states ->
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

  defp get_elevator_states do
    for elevator_id <- get_elevator_ids(), into: %{} do
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

  defp elevator_has_floor_selected?(elevators, elevator_id, floor) do
    case elevators[elevator_id] do
      nil -> false
      control_unit -> MapSet.member?(control_unit.internal_queue, floor)
    end
  end
end
