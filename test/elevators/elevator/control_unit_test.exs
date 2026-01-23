defmodule Elevators.Elevator.ControlUnitTest do
  alias Elevators.Elevator.ControlUnit

  defmodule Distances do
    use ExUnit.Case

    test "regular distance" do
      assert ControlUnit.travel_weight(%ControlUnit{floor: 2}, 0) == 2
    end

    test "requested up but going down" do
      assert ControlUnit.travel_weight(
               %ControlUnit{floor: 2, state: :going_down, internal_queue: MapSet.new([-1])},
               3
             ) == 7
    end

    test "requested down but going up" do
      assert ControlUnit.travel_weight(
               %ControlUnit{floor: 2, state: :going_up, internal_queue: MapSet.new([5])},
               1
             ) == 7
    end
  end

  defmodule Movement do
    use ExUnit.Case

    test "idle elevator stays put" do
      idle = %ControlUnit{
        state: :going_up,
        floor: 1,
        internal_queue: MapSet.new(),
        external_calls: %{}
      }

      assert ControlUnit.move(idle) == {idle, nil}
    end

    test "up goes up even when lower floor closer" do
      init = %ControlUnit{floor: 0, state: :going_up, internal_queue: MapSet.new([-1, 1000])}
      {result, _} = ControlUnit.move(init)
      assert result.floor == 1
      assert result.state == :going_up
    end

    test "elevator stops at requested floor" do
      init = %ControlUnit{floor: 1, state: :going_up, internal_queue: MapSet.new([2])}
      {result, _} = ControlUnit.move(init)
      assert result.floor == 2
      assert result.doors_open == true
      assert result.internal_queue == MapSet.new()
    end

    test "elevator changes direction" do
      init = %ControlUnit{floor: 1, state: :going_up, internal_queue: MapSet.new([2, -1])}
      # First move to floor 2
      {at_floor_2, _} = ControlUnit.move(init)
      assert at_floor_2.floor == 2
      assert at_floor_2.doors_open == true
      # After doors close and next move, should go down
      {closed_doors, _} = ControlUnit.move(at_floor_2)
      {going_down, _} = ControlUnit.move(closed_doors)
      assert going_down.floor == 1
      assert going_down.state == :going_down
    end
  end

  defmodule FloorSelection do
    use ExUnit.Case

    test "selecting current has no effect" do
      init = %ControlUnit{floor: 1}
      assert ControlUnit.select_floor(init, 1) == init
    end

    test "stationary with button pressed goes" do
      init = %ControlUnit{state: :stationary}
      desired = %ControlUnit{init | state: {:going_up, MapSet.new([2])}}
      assert ControlUnit.select_floor(init, 2) == desired
    end

    test "selection does not change direction" do
      init = %ControlUnit{state: {:going_up, MapSet.new([2])}}
      desired = %ControlUnit{state: {:going_up, MapSet.new([2, -1])}}
      assert ControlUnit.select_floor(init, -1) == desired
    end
  end
end
