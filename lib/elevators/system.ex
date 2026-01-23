defmodule Elevators.System do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {Registry, keys: :unique, name: Elevators.Registry},
      Elevators.Dispatcher,
      Elevators.Floors,
      Elevators.Elevators
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
