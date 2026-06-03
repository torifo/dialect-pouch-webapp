defmodule DialectPocket.Repo do
  use Ecto.Repo,
    otp_app: :dialect_pocket,
    adapter: Ecto.Adapters.Postgres
end
