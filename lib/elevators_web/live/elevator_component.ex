defmodule ElevatorsWeb.Live.ElevatorComponent do
  use ElevatorsWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign_new(:id, fn -> assigns.id end)
      |> assign_new(:elevator_id, fn -> assigns[:elevator_id] end)
      |> assign_new(:floors, fn -> assigns[:floors] end)

    socket =
      if Map.has_key?(assigns, :control_unit) do
        assign(socket, :control_unit, assigns.control_unit)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex gap-6">
      <!-- Elevator shaft visualization -->
      <div class="flex flex-col-reverse gap-3">
        <div class="font-bold text-lg mb-3 text-center text-base-content">
          Elevator {@elevator_id}
        </div>
        <div :for={floor <- @floors} class="h-24 flex items-center justify-center">
          <div class={[
            "w-32 h-20 border-4 rounded-lg relative overflow-hidden transition-all shadow-lg",
            (at_floor?(@control_unit, floor) && "border-accent shadow-accent/50") || "border-base-300"
          ]}>
            <%= if at_floor?(@control_unit, floor) do %>
              <!-- Elevator interior background -->
              <div class="absolute inset-0 bg-base-100 flex items-center justify-center">
                <span class="text-3xl z-10 text-accent font-bold">
                  {direction_arrow(@control_unit)}
                </span>
              </div>
              
    <!-- Left door -->
              <div class={[
                "absolute top-0 bottom-0 left-0 bg-gradient-to-r from-gray-400 to-gray-500 border-r border-gray-600 transition-all duration-700 ease-in-out shadow-inner",
                (doors_open?(@control_unit) && "w-0") || "w-1/2"
              ]}>
              </div>
              
    <!-- Right door -->
              <div class={[
                "absolute top-0 bottom-0 right-0 bg-gradient-to-l from-gray-400 to-gray-500 border-l border-gray-600 transition-all duration-700 ease-in-out shadow-inner",
                (doors_open?(@control_unit) && "w-0") || "w-1/2"
              ]}>
              </div>
            <% else %>
              <!-- Empty shaft -->
              <div class="absolute inset-0 bg-base-200"></div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Control Panel -->
      <div class="flex flex-col gap-3">
        <div class="font-bold text-lg mb-3 text-center text-base-content">Panel</div>
        <div class="card bg-neutral shadow-xl">
          <div class="card-body p-4">
            <div class="flex flex-wrap gap-2 justify-center max-w-xs">
              <button
                :for={floor <- Enum.reverse(@floors)}
                phx-click="select_floor"
                phx-value-elevator={@elevator_id}
                phx-value-floor={floor}
                phx-target={@myself}
                class={[
                  "btn btn-sm font-mono font-bold transition-all min-w-[3rem] min-h-[3rem] btn-ghost",
                  (floor_selected?(@control_unit, floor) && "text-primary") || "text-neutral-content"
                ]}
              >
                {floor}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_floor", %{"elevator" => elevator_id_str, "floor" => floor_str}, socket) do
    elevator_id = String.to_integer(elevator_id_str)
    floor = String.to_integer(floor_str)
    Elevators.Elevator.select_floor(elevator_id, floor)
    {:noreply, socket}
  end

  defp at_floor?(control_unit, floor) do
    control_unit && control_unit.floor == floor
  end

  defp doors_open?(control_unit) do
    control_unit && control_unit.doors_open
  end

  defp direction_arrow(control_unit) do
    case control_unit && control_unit.state do
      :going_up -> "↑"
      :going_down -> "↓"
      _ -> ""
    end
  end

  defp floor_selected?(control_unit, floor) do
    control_unit && MapSet.member?(control_unit.internal_queue, floor)
  end
end
