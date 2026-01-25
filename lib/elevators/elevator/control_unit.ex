defmodule Elevators.Elevator.ControlUnit do
  @moduledoc """
  The control unit is responsible for managing the state of an elevator

  It keeps track of the current floor, the direction of movement, the doors state, and in case it's moving, the selected floors
  """
  defstruct state: :going_up,
            floor: 0,
            doors_open: true,
            internal_queue: MapSet.new(),
            external_calls: %{}

  @type direction :: :going_up | :going_down

  @type t :: %__MODULE__{
          state: :going_up | :going_down,
          internal_queue: MapSet.t(integer()),
          external_calls: %{integer() => direction()},
          floor: integer(),
          doors_open: boolean()
        }

  @spec select_floor(t(), integer()) :: t()
  @doc """
  Sets the elevator in motion in the direction of your picked floor

  Should you ask for a floor that is not in the direction the elevator is already taking (yes, this happens all the time with absent-minded folks), it will continue on its path until it reaches the last requested floor in that direction

  Does nothing if you're already on that floor
  """
  def select_floor(%__MODULE__{floor: target} = elevator, target) do
    elevator
  end

  def select_floor(%__MODULE__{internal_queue: queue} = elevator, target) do
    %{elevator | internal_queue: MapSet.put(queue, target)}
  end

  @spec dispatch_to(t(), integer(), :going_up | :going_down) :: t()
  @doc """
  Assigns an external floor call to this elevator from the dispatcher

  The elevator will stop at this floor when moving in the specified direction
  """
  def dispatch_to(%__MODULE__{external_calls: calls} = elevator, floor, direction) do
    %{elevator | external_calls: Map.put(calls, floor, direction)}
  end

  @spec move(t()) :: t()
  @spec move(Elevators.Elevator.ControlUnit.t()) ::
          {Elevators.Elevator.ControlUnit.t(), direction()}
  @doc """
  Will continue on its path as long as there are floors to reach

  If the only remaining floors are in the other direction, it switches direction
  """
  def move(%__MODULE__{doors_open: true} = elevator), do: {%{elevator | doors_open: false}, nil}

  def move(
        %__MODULE__{
          state: direction,
          floor: floor,
          internal_queue: internal,
          external_calls: external
        } = elevator
      ) do
    # Get all remaining destinations
    all_remaining = MapSet.union(internal, MapSet.new(Map.keys(external)))

    # Check if there are more destinations ahead in current direction (excluding current floor)
    has_destinations_ahead =
      if direction == :going_up do
        Enum.any?(all_remaining, fn f -> f > floor end)
      else
        Enum.any?(all_remaining, fn f -> f < floor end)
      end

    # Check if we should stop at the CURRENT floor before moving
    # Also stop for external calls if this is the last stop in current direction
    should_stop_here =
      MapSet.member?(internal, floor) or
        Map.get(external, floor) == direction or
        (Map.has_key?(external, floor) and not has_destinations_ahead)

    if should_stop_here do
      # Determine which external call direction we're servicing (if any)
      serviced_direction = Map.get(external, floor)

      # Update elevator direction to match the external call if present
      new_direction = serviced_direction || direction

      # Open doors at current floor and clear it from queues
      updated_elevator = %{
        elevator
        | doors_open: true,
          state: new_direction,
          internal_queue: MapSet.delete(internal, floor),
          external_calls: Map.delete(external, floor)
      }

      # Return elevator state with metadata about what was serviced
      {updated_elevator, serviced_direction}
    else
      # Don't move if there are no destinations
      if Enum.empty?(all_remaining) do
        {elevator, nil}
      else
        # Determine which direction to move based on where destinations are
        move_direction =
          cond do
            # If there are floors ahead in current direction, keep going
            direction == :going_up and Enum.any?(all_remaining, &(&1 > floor)) ->
              :going_up

            direction == :going_down and Enum.any?(all_remaining, &(&1 < floor)) ->
              :going_down

            # Otherwise switch to go towards destinations
            Enum.any?(all_remaining, &(&1 < floor)) ->
              :going_down

            Enum.any?(all_remaining, &(&1 > floor)) ->
              :going_up

            # Shouldn't reach here, but maintain direction
            true ->
              direction
          end

        # Move one floor in the chosen direction
        next_floor = floor + if move_direction == :going_up, do: 1, else: -1

        {%{elevator | floor: next_floor, state: move_direction}, nil}
      end
    end
  end

  def travel_weight(
        %__MODULE__{
          floor: floor,
          state: direction,
          internal_queue: internal,
          external_calls: external
        },
        desired_floor
      ) do
    abs_distance = distance(floor, desired_floor)
    all_remaining = MapSet.union(internal, MapSet.new(Map.keys(external)))

    if Enum.empty?(all_remaining) do
      abs_distance
    else
      case direction do
        :going_up ->
          if desired_floor >= floor do
            abs_distance
          else
            max = Enum.max(all_remaining)
            distance(floor, max) + distance(desired_floor, max)
          end

        :going_down ->
          if desired_floor <= floor do
            abs_distance
          else
            min = Enum.min(all_remaining)
            distance(floor, min) + distance(desired_floor, min)
          end
      end
    end
  end

  defp distance(rhs, lhs) do
    abs(rhs - lhs)
  end
end
