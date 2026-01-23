defmodule Elevators.Elevator do
  alias Elevators.Elevator.ControlUnit
  use GenServer

  defmodule State do
    defstruct [:id, :control_unit]

    @type t :: %__MODULE__{
            id: integer(),
            control_unit: ControlUnit.t()
          }
  end

  def start_link([elevator_id]) do
    GenServer.start_link(__MODULE__, elevator_id, name: via_tuple(elevator_id))
  end

  def move(elevator_id) do
    GenServer.cast(via_tuple(elevator_id), :move)
  end

  def select_floor(elevator_id, floor) do
    GenServer.cast(via_tuple(elevator_id), {:select_floor, floor})
  end

  def dispatch_to(elevator_id, floor, direction) do
    GenServer.cast(via_tuple(elevator_id), {:dispatch_to, floor, direction})
  end

  def get_state(elevator_id) do
    GenServer.call(via_tuple(elevator_id), :get_state)
  end

  @impl GenServer
  def init(elevator_id) do
    IO.puts("Initializing elevator #{elevator_id}")

    Task.start(fn ->
      :timer.sleep(1000)
      GenServer.cast(via_tuple(elevator_id), :move)
    end)

    {:ok, %State{id: elevator_id, control_unit: %ControlUnit{}}}
  end

  defp via_tuple(elevator_id) do
    {:via, Registry, {Elevators.Registry, {:elevator, elevator_id}}}
  end

  @impl GenServer
  def handle_cast(:move, state) do
    new_control_unit = ControlUnit.move(state.control_unit)

    direction = new_control_unit.state

    Phoenix.PubSub.broadcast(Elevators.PubSub, "elevator:#{state.id}", %{
      event: :moving,
      elevator_id: state.id,
      floor: new_control_unit.floor,
      direction: direction
    })

    # Broadcast arrival event if doors opened
    if new_control_unit.doors_open do
      Phoenix.PubSub.broadcast(Elevators.PubSub, "elevator:arrived", %{
        event: :arrived,
        elevator_id: state.id,
        floor: new_control_unit.floor,
        direction: direction
      })
    end

    # Schedule the next move
    Task.start(fn ->
      :timer.sleep(1000)
      GenServer.cast(via_tuple(state.id), :move)
    end)

    IO.puts("Elevator #{state.id} is now on floor #{new_control_unit.floor}")
    {:noreply, %{state | control_unit: new_control_unit}}
  end

  @impl GenServer
  def handle_cast({:select_floor, floor}, state) do
    new_control_unit = ControlUnit.select_floor(state.control_unit, floor)
    {:noreply, %{state | control_unit: new_control_unit}}
  end

  @impl GenServer
  def handle_cast({:dispatch_to, floor, direction}, state) do
    new_control_unit = ControlUnit.dispatch_to(state.control_unit, floor, direction)
    {:noreply, %{state | control_unit: new_control_unit}}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
