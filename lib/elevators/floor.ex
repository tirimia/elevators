defmodule Elevators.Floor do
  use GenServer

  defmodule State do
    defstruct [:number, wants_up: false, wants_down: false]

    @type t :: %__MODULE__{
            number: integer(),
            wants_up: boolean(),
            wants_down: boolean()
          }
  end

  @spec start_link([integer()]) :: GenServer.on_start()
  def start_link([floor_number]) do
    GenServer.start_link(__MODULE__, floor_number, name: via_tuple(floor_number))
  end

  @impl true
  @spec init(integer()) :: {:ok, Elevators.Floor.State.t()}
  def init(floor_number) do
    IO.puts("Initializing floor #{floor_number}")
    Phoenix.PubSub.subscribe(Elevators.PubSub, "elevator:arrived")
    {:ok, %State{number: floor_number}}
  end

  defp via_tuple(floor_number) do
    {:via, Registry, {Elevators.Registry, {:floor, floor_number}}}
  end

  def wants_up?(floor_number) do
    GenServer.call(via_tuple(floor_number), :wants_up?)
  end

  def wants_down?(floor_number) do
    GenServer.call(via_tuple(floor_number), :wants_down?)
  end

  def press_up_button(floor_number) do
    GenServer.cast(via_tuple(floor_number), :press_up)
  end

  def press_down_button(floor_number) do
    GenServer.cast(via_tuple(floor_number), :press_down)
  end

  @impl true
  def handle_call(:wants_up?, _from, state) do
    {:reply, state.wants_up, state}
  end

  @impl true
  def handle_call(:wants_down?, _from, state) do
    {:reply, state.wants_down, state}
  end

  @impl true
  def handle_cast(:press_up, state) do
    Phoenix.PubSub.broadcast(Elevators.PubSub, "floor:call", %{
      floor: state.number,
      direction: :going_up
    })

    {:noreply, %{state | wants_up: true}}
  end

  @impl true
  def handle_cast(:press_down, state) do
    Phoenix.PubSub.broadcast(Elevators.PubSub, "floor:call", %{
      floor: state.number,
      direction: :going_down
    })

    {:noreply, %{state | wants_down: true}}
  end

  @impl true
  def handle_info(%{event: :arrived, floor: floor, direction: direction}, state)
      when floor == state.number do
    # Clear the flag that matches the elevator's direction
    new_state =
      case direction do
        :going_up -> %{state | wants_up: false}
        :going_down -> %{state | wants_down: false}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    # Ignore other elevator arrival messages
    {:noreply, state}
  end
end
