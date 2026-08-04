#!/usr/bin/env bash
set -eo pipefail

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  c_reset=$'\033[0m'
  c_blue=$'\033[1;34m'
  c_red=$'\033[1;31m'
else
  c_reset=''
  c_blue=''
  c_red=''
fi

info() { printf '%b[mcp-wrapper]%b %s\n' "$c_blue" "$c_reset" "$*"; }
fail() { printf '%b[mcp-wrapper]%b %s\n' "$c_red" "$c_reset" "$*"; }

if [[ -z ${CLICKUP_API_TOKEN:-} ]]; then
  fail "CLICKUP_API_TOKEN is required" >&2
  exit 1
fi

info "starting mcp-clickup-server"
exec mcp-clickup-server
