import Config

config :elevators,
  generators: [timestamp_type: :utc_datetime]

config :elevators, Elevators.System,
  # Consider just passing a range instead
  lowest_floor: -2,
  highest_floor: 5,
  num_elevators: 3

# Configure the endpoint
config :elevators, ElevatorsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ElevatorsWeb.ErrorHTML, json: ElevatorsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Elevators.PubSub,
  live_view: [signing_salt: "vTrZod0L"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  elevators: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  elevators: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
