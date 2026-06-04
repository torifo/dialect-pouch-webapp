#!/usr/bin/env bash
# dialect-pouch dev toolchain setup (macOS / Homebrew / asdf)
# Installs Erlang + Elixir via asdf and the Phoenix project generator.
# Erlang is compiled from source on first install (10-20 min).
set -euo pipefail

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# --- Homebrew env ---
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
else
  echo "Homebrew not found" >&2; exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- asdf ---
if ! command -v asdf >/dev/null 2>&1; then
  log "Installing asdf"
  brew install asdf
fi
# new (Go) asdf: data dir + shims
export ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
export PATH="$ASDF_DATA_DIR/shims:$(brew --prefix asdf)/libexec/bin:$PATH"
log "asdf version: $(asdf --version 2>&1 || true)"

# --- Erlang build dependencies ---
log "Installing Erlang build deps via brew"
brew install autoconf openssl@3 wxwidgets libxslt unixodbc >/dev/null 2>&1 || \
  brew install autoconf openssl@3 wxwidgets libxslt unixodbc

# kerl options: link openssl, skip docs to speed up
export KERL_CONFIGURE_OPTIONS="--with-ssl=$(brew --prefix openssl@3) --enable-dynamic-ssl-lib"
export KERL_BUILD_DOCS=no
export CC="${CC:-clang}"

# --- plugins ---
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git 2>/dev/null || true
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git 2>/dev/null || true

# --- pick latest stable OTP 27 + matching Elixir ---
log "Resolving versions"
ERL_VER="$(asdf list all erlang | grep -E '^27\.[0-9]+(\.[0-9]+)?$' | tail -1)"
[ -n "${ERL_VER:-}" ] || ERL_VER="$(asdf list all erlang | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | tail -1)"
ERL_MAJOR="${ERL_VER%%.*}"
EX_VER="$(asdf list all elixir | grep -E -- "-otp-${ERL_MAJOR}$" | grep -viE 'rc|main' | tail -1)"
[ -n "${EX_VER:-}" ] || EX_VER="$(asdf list all elixir | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | tail -1)"
echo "Erlang -> $ERL_VER"
echo "Elixir -> $EX_VER"

# --- install ---
log "Installing Erlang $ERL_VER (this compiles from source; be patient)"
asdf install erlang "$ERL_VER"
log "Installing Elixir $EX_VER"
asdf install elixir "$EX_VER"

# --- pin versions for the project (.tool-versions) ---
log "Writing .tool-versions"
{
  echo "erlang $ERL_VER"
  echo "elixir $EX_VER"
} > "$REPO_DIR/.tool-versions"
asdf reshim || true

# --- Phoenix generator ---
log "Installing hex / rebar / phx_new"
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force

log "DONE. Erlang $ERL_VER / Elixir $EX_VER ready."
elixir --version || true
