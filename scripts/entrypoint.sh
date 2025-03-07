#!/bin/bash

set -euo pipefail

echo "Action Stat!"
echo "Version: $(cat /version)"

git config --global --add safe.directory "${GITHUB_WORKSPACE}"
cd "${GITHUB_WORKSPACE}"

# Get workflow logs
/usr/local/bin/collect-logs.sh

export GITHUB_REPOSITORY=$(gh repo view --json nameWithOwner -q .nameWithOwner)
export WORKFLOW_ID=$(gh run view "${WORKFLOW_RUN_ID}" --json workflowDatabaseId -q .workflowDatabaseId)
export WORKFLOW_NAME=$(gh run view "${WORKFLOW_RUN_ID}" --json workflowName -q .workflowName)

if [ -z "${TELEMETRY_URL:-}" ]; then
  echo "TELEMETRY_URL is not set!"
  exit 1
fi

if [ -z "${TELEMETRY_USERNAME:-}" ]; then
  echo "TELEMETRY_USERNAME is not set!"
  exit 1
fi

if [ -z "${TELEMETRY_PASSWORD:-}" ]; then
  echo "TELEMETRY_PASSWORD is not set!"
  exit 1
fi

# Run alloy in the background and save its PID
alloy run /etc/alloy/gha-observability.alloy \
  --storage.path "/tmp/alloy" \
  --stability.level experimental \
  --disable-reporting &
ALLOY_PID=$!

# Set timeout duration (5 minutes = 300 seconds)
UPLOAD_TIMEOUT=${UPLOAD_TIMEOUT:-300}
START_TIME=${SECONDS}

# Watch for file contents of log direcotry to be deleted or timeout
while true; do
  # Check if timeout reached
  if [[ $((SECONDS - START_TIME)) -ge "${UPLOAD_TIMEOUT}" ]]; then
    echo "Timeout reached after ${UPLOAD_TIMEOUT} seconds. Killing Alloy process."
    kill "${ALLOY_PID}" || true
    return 1
  fi

  # Check if log directory is empty
  if [[ -z "$(ls -A "${LOGS_DIRECTORY}")" ]]; then
    kill "${ALLOY_PID}" || true
    break
  fi
done
