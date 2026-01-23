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

  @type t :: %__MODULE__{
          state: :going_up | :going_down,
          internal_queue: MapSet.t(integer()),
          external_calls: %{integer() => :going_up | :going_down},
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
  @doc """
  Will continue on its path as long as there are floors to reach

  If the only remaining floors are in the other direction, it switches direction
  """
  def move(%__MODULE__{doors_open: true} = elevator), do: %{elevator | doors_open: false}

  def move(
        %__MODULE__{
          state: direction,
          floor: floor,
          internal_queue: internal,
          external_calls: external
        } = elevator
      ) do
    # Get all floors from both queues
    all_remaining = MapSet.union(internal, MapSet.new(Map.keys(external)))

    # Don't move if there are no floors to visit
    if Enum.empty?(all_remaining) do
      elevator
    else
      # Determine next floor based on current direction
      next_floor = floor + if direction == :going_up, do: 1, else: -1

      # Check if we should stop at this floor (internal button or external call matches direction)
      should_open_doors =
        MapSet.member?(internal, next_floor) or Map.get(external, next_floor) == direction

      # Remove this floor from both queues if we're stopping
      new_internal =
        if should_open_doors, do: MapSet.delete(internal, next_floor), else: internal

      new_external = if should_open_doors, do: Map.delete(external, next_floor), else: external

      # Get all remaining floors from both queues after this move
      remaining_after_move = MapSet.union(new_internal, MapSet.new(Map.keys(new_external)))

      # Determine next direction based on remaining floors
      next_direction =
        cond do
          # Continue in current direction if there are floors ahead
          direction == :going_up and Enum.any?(remaining_after_move, &(&1 > next_floor)) ->
            :going_up

          direction == :going_down and Enum.any?(remaining_after_move, &(&1 < next_floor)) ->
            :going_down

          # Switch direction if there are floors behind
          direction == :going_up and Enum.any?(remaining_after_move, &(&1 < next_floor)) ->
            :going_down

          direction == :going_down and Enum.any?(remaining_after_move, &(&1 > next_floor)) ->
            :going_up

          # No floors left, maintain current direction
          true ->
            direction
        end

      %{
        elevator
        | state: next_direction,
          floor: next_floor,
          doors_open: should_open_doors,
          internal_queue: new_internal,
          external_calls: new_external
      }
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
