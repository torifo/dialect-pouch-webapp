defmodule DialectPouch.RateLimiter do
  @moduledoc """
  ETS-backed rate limiter (Hammer v7). Throttles anonymous contributions.

  Started in the supervision tree as
  `{DialectPouch.RateLimiter, [clean_period: :timer.minutes(10)]}`.
  Use `hit/3`: returns `{:allow, count}` or `{:deny, retry_after_ms}`.
  """
  use Hammer, backend: :ets
end
