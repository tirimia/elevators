defmodule Elevators.Pubsub.Client do
  def start() do
    Phoenix.PubSub.subscribe(Elevators.PubSub, "elevators")
  end
end
