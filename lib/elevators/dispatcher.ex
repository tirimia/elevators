defmodule Elevators.Dispatcher do
  @moduledoc """
  Centralized dispatcher that assigns floor calls to optimal elevators

  Subscribes to floor:call events and coordinates elevator selection
  """
  use GenServer
  alias Elevators.Elevator.ControlUnit

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(Elevators.PubSub, "floor:call")
    {:ok, %{}}
  end

  @impl true
  def handle_info(%{floor: floor, direction: direction}, state) do
    elevator_states = get_all_elevator_states()

    # Filter out elevators already assigned to this floor with a different direction
    available_elevators =
      Enum.reject(elevator_states, fn {_id, control_unit} ->
        case Map.get(control_unit.external_calls, floor) do
          nil -> false
          ^direction -> false  # Same direction is ok, they can share
          _other_direction -> true  # Different direction - exclude this elevator
        end
      end)

    # If all elevators are already assigned to this floor (shouldn't happen), use all
    candidates = if Enum.empty?(available_elevators), do: elevator_states, else: available_elevators

    optimal_elevator =
      candidates
      |> Enum.min_by(fn {_id, control_unit} ->
        ControlUnit.travel_weight(control_unit, floor)
      end)
      |> elem(0)

    Elevators.Elevator.dispatch_to(optimal_elevator, floor, direction)

    {:noreply, state}
  end

  defp get_all_elevator_states do
    Registry.select(Elevators.Registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(fn
      {{:elevator, _id}, _pid} -> true
      _ -> false
    end)
    |> Task.async_stream(
      fn {{:elevator, id}, pid} ->
        state = GenServer.call(pid, :get_state)
        {id, state.control_unit}
      end,
      timeout: 5000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end
end
