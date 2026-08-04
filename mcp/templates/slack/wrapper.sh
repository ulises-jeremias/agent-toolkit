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

if [[ -z ${SLACK_BOT_TOKEN:-} || -z ${SLACK_APP_TOKEN:-} ]]; then
  fail "SLACK_BOT_TOKEN and SLACK_APP_TOKEN are required" >&2
  exit 1
fi

info "starting mcp-slack-server"
exec mcp-slack-server
