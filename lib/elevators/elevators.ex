defmodule Elevators.Elevators do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    num_elevators = Application.get_env(:elevators, Elevators.System)[:num_elevators]

    children =
      for elevator_id <- 1..num_elevators do
        Supervisor.child_spec({Elevators.Elevator, [elevator_id]}, id: elevator_id)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
