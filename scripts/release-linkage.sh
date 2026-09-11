#!/usr/bin/env bash
# release-linkage.sh — single source of truth for V production link flags
# and binary portability gates (follow-up to #1199).
#
# Usage:
#   scripts/release-linkage.sh flags
#       Print the `v` flags for production release builds on this runner OS.
#   scripts/release-linkage.sh gate <binary>...
#       Enforce the per-OS portability gate; exit 1 on violation.
#
# OS resolution: $RUNNER_OS on GitHub Actions, otherwise `uname -s`
# (Darwin -> macOS, MINGW*/MSYS*/CYGWIN* -> Windows), so the gate doubles
# as a local release-verification tool.
#
# Flag policy (proven by the release.yml `linkage-smoke` job on all 3 OSes):
#   macOS: -prod -cc clang — V's default tcc backend bakes a
#     runner-absolute @rpath/libgc.dylib (~/vlang-master/thirdparty/tcc)
#     that aborts user machines with `dyld: Library not loaded` (1.30.0);
#     upstream V reserves tcc for dev builds.
#   Linux: -prod -cc gcc — same tcc avoidance; the ldd gate proves it.
#   Windows: -prod over the toolchain default — uniform production flags on
#     every OS (that leg runs the V 0.5.2 fallback, see setup-v).
#
# Gate policy:
#   macOS: otool -L must show no /Users/runner, /home/runner,
#     thirdparty/tcc or @rpath/libgc refs.
#   Linux: ldd must show no `not found` entries.
#   Windows: DLL inventory is logged for review (log-only — there is no
#     curated system-DLL allowlist to gate against).
#
# Do NOT re-inline per-OS flags or gate patterns in release.yml: the smoke
# job only proves the release build while both call this script.
set -euo pipefail

os_name() {
  # A set-but-unknown RUNNER_OS is a hard error: silently falling back to
  # `uname` would apply the wrong flags on a misconfigured runner.
  if [ -n "${RUNNER_OS:-}" ]; then
    case "${RUNNER_OS}" in
      macOS | Linux) printf '%s' "${RUNNER_OS}" && return 0 ;;
      Windows*) printf 'Windows' && return 0 ;;
      *)
        echo "release-linkage: unsupported RUNNER_OS=${RUNNER_OS}" >&2
        return 1
        ;;
    esac
  fi
  case "$(uname -s)" in
    Darwin) printf 'macOS' ;;
    Linux) printf 'Linux' ;;
    MINGW* | MSYS* | CYGWIN* | Windows*) printf 'Windows' ;;
    *)
      echo "release-linkage: unsupported OS (RUNNER_OS=${RUNNER_OS:-}, uname=$(uname -s))" >&2
      return 1
      ;;
  esac
}

gh_error() {
  if [ "${GITHUB_ACTIONS:-}" = 'true' ]; then
    echo "::error::$1" >&2
  else
    echo "ERROR: $1" >&2
  fi
}

cmd_flags() {
  # NOTE: `case "$(os_name)"` would swallow os_name's failure (an empty
  # substitution matches no branch and the case exits 0), so resolve first.
  _os="$(os_name)" || return 1
  case "${_os}" in
    macOS) printf '%s' '-prod -cc clang' ;;
    Linux) printf '%s' '-prod -cc gcc' ;;
    Windows) printf '%s' '-prod' ;;
  esac
}

cmd_gate() {
  if [ "$#" -eq 0 ]; then
    echo 'release-linkage: gate needs at least one binary' >&2
    return 1
  fi
  # See cmd_flags: resolve the OS first so a detection failure is fatal.
  _os="$(os_name)" || return 1
  case "${_os}" in
    macOS)
      otool -L "$@"
      if otool -L "$@" | grep -E '/Users/runner|/home/runner|thirdparty/tcc|@rpath/libgc'; then
        gh_error "non-portable linkage (see otool above)"
        return 1
      fi
      echo 'macOS linkage: portable (no runner-absolute libgc)'
      ;;
    Linux)
      ldd "$@"
      if ldd "$@" | grep -q 'not found'; then
        gh_error "unresolved shared libraries (see ldd above)"
        return 1
      fi
      echo 'Linux linkage: all shared libraries resolved'
      ;;
    Windows)
      # log-only inventory for review (see header: no allowlist to gate on)
      for bin in "$@"; do
        (objdump -p "${bin}" 2>/dev/null | grep 'DLL Name' || echo 'objdump unavailable') | sort -u
      done
      ;;
  esac
}

case "${1:-}" in
  flags) cmd_flags ;;
  gate)
    shift
    cmd_gate "$@"
    ;;
  *)
    echo "usage: $0 {flags|gate <binary>...}" >&2
    exit 2
    ;;
esac
