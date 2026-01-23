defmodule Elevators.Schedulers.Ticker do
  use GenServer
  require Logger

  def subscribe() do
    Phoenix.PubSub.subscribe(Elevators.PubSub, "elevators")
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, 1000)
    schedule_job(0)
    {:ok, %{interval_ms: interval_ms}}
  end

  @impl true
  def handle_info(:run_job, state) do
    Phoenix.PubSub.broadcast(Elevators.PubSub, "elevators", :progress)
    schedule_job(state.interval_ms)
    {:noreply, state}
  end

  defp schedule_job(delay_ms) do
    Process.send_after(self(), :run_job, delay_ms)
  end
end
