defmodule Elevators.Elevator.ControlUnitTest do
  alias Elevators.Elevator.ControlUnit

  defmodule Distances do
    use ExUnit.Case

    test "regular distance" do
      assert ControlUnit.travel_weight(%ControlUnit{floor: 2}, 0) == 2
    end

    test "requested up but going down" do
      assert ControlUnit.travel_weight(
               %ControlUnit{floor: 2, state: {:going_down, MapSet.new([-1])}},
               3
             ) == 7
    end

    test "requested down but going up" do
      assert ControlUnit.travel_weight(
               %ControlUnit{floor: 2, state: {:going_up, MapSet.new([5])}},
               1
             ) == 7
    end
  end

  defmodule Movement do
    use ExUnit.Case

    test "idle stationary stays put" do
      stationary = %ControlUnit{state: :stationary, floor: 1}
      assert ControlUnit.move(stationary) == stationary
    end

    test "up goes up even when lower floor closer" do
      buttons_pressed = MapSet.new([-1, 1000])
      init = %ControlUnit{floor: 0, state: {:going_up, buttons_pressed}}
      desired = %ControlUnit{floor: 1, state: {:going_up, buttons_pressed}}
      assert ControlUnit.move(init) == desired
    end

    test "elevator stops at the last stop" do
      init = %ControlUnit{floor: 1, state: {:going_up, MapSet.new([2])}}
      desired = %ControlUnit{floor: 2, state: :stationary}
      assert ControlUnit.move(init) == desired
    end

    test "elevator changes direction" do
      init = %ControlUnit{floor: 1, state: {:going_up, MapSet.new([2, -1])}}
      desired = %ControlUnit{floor: 2, state: {:going_down, MapSet.new([-1])}}
      assert ControlUnit.move(init) == desired
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
