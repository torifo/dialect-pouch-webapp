# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dialect_pocket, :scopes,
  admin: [
    default: true,
    module: DialectPocket.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:admin, :id],
    schema_key: :admin_id,
    schema_type: :id,
    schema_table: :admins,
    test_data_fixture: DialectPocket.AccountsFixtures,
    test_setup_helper: :register_and_log_in_admin
  ]

config :dialect_pocket,
  ecto_repos: [DialectPocket.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :dialect_pocket, DialectPocketWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DialectPocketWeb.ErrorHTML, json: DialectPocketWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DialectPocket.PubSub,
  live_view: [signing_salt: "l9XAK7To"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dialect_pocket, DialectPocket.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  dialect_pocket: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  dialect_pocket: [
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

# Oban: persistent job queue (open-data ingestion, LLM enrichment, sitemap).
config :dialect_pocket, Oban,
  repo: DialectPocket.Repo,
  queues: [default: 10, ingestion: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
