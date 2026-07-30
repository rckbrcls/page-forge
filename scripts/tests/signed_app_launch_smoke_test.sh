#!/bin/bash

set -euo pipefail

APP_PATH=""
MINIMUM_SECONDS=5

usage() {
  echo "Usage: signed_app_launch_smoke_test.sh --app <absolute-app-path> [--minimum-seconds <seconds>]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --app."
        exit 1
      fi
      APP_PATH="$2"
      shift 2
      ;;
    --minimum-seconds)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --minimum-seconds."
        exit 1
      fi
      MINIMUM_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "The signed app launch smoke test only supports macOS."
  exit 1
fi
if [[ "$APP_PATH" != /* ]] || [ ! -d "$APP_PATH" ]; then
  echo "The app path must reference an absolute existing app bundle."
  exit 1
fi
if ! [[ "$MINIMUM_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "The minimum launch duration must be a positive integer."
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
if [ ! -x "$APP_EXECUTABLE" ]; then
  echo "The app executable is missing or not executable."
  exit 1
fi

TEMP_DIRECTORY=$(mktemp -d)
STDOUT_LOG="$TEMP_DIRECTORY/stdout.log"
STDERR_LOG="$TEMP_DIRECTORY/stderr.log"
APP_PID=""

cleanup() {
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill -TERM "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$STDOUT_LOG" "$STDERR_LOG"
  rmdir "$TEMP_DIRECTORY" 2>/dev/null || true
}
trap cleanup EXIT

"$APP_EXECUTABLE" >"$STDOUT_LOG" 2>"$STDERR_LOG" &
APP_PID=$!

elapsed_seconds=0
while [ "$elapsed_seconds" -lt "$MINIMUM_SECONDS" ]; do
  sleep 1
  elapsed_seconds=$((elapsed_seconds + 1))
  if ! kill -0 "$APP_PID" >/dev/null 2>&1; then
    set +e
    wait "$APP_PID"
    exit_status=$?
    set -e
    echo "The signed app exited before the ${MINIMUM_SECONDS}-second launch gate (status ${exit_status})."
    if [ -s "$STDERR_LOG" ]; then
      echo "Signed app stderr:"
      sed -n '1,80p' "$STDERR_LOG"
    fi
    exit 1
  fi
done

kill -TERM "$APP_PID"
set +e
wait "$APP_PID"
exit_status=$?
set -e
APP_PID=""

if [ "$exit_status" -ne 0 ] && [ "$exit_status" -ne 143 ]; then
  echo "The signed app did not terminate cleanly after the launch gate (status ${exit_status})."
  if [ -s "$STDERR_LOG" ]; then
    echo "Signed app stderr:"
    sed -n '1,80p' "$STDERR_LOG"
  fi
  exit 1
fi

echo "Signed app launch smoke test passed."
