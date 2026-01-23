defmodule Elevators.Floors do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    lowest_floor = Application.get_env(:elevators, Elevators.System)[:lowest_floor]
    highest_floor = Application.get_env(:elevators, Elevators.System)[:highest_floor]

    children =
      for floor_number <- lowest_floor..highest_floor do
        Supervisor.child_spec({Elevators.Floor, [floor_number]}, id: floor_number)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
