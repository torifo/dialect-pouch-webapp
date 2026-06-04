defmodule DialectPouch.Repo do
  use Ecto.Repo,
    otp_app: :dialect_pouch,
    adapter: Ecto.Adapters.Postgres
end
