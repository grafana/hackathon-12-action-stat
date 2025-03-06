#!/bin/bash

set -euo pipefail

echo "Action Stat!"
echo "Version: $(cat /version)"

git config --global --add safe.directory "${GITHUB_WORKSPACE}"
cd "${GITHUB_WORKSPACE}"

# Get workflow logs
/usr/local/bin/get-logs.sh

export GITHUB_REPOSITORY=$(gh repo view --json nameWithOwner -q .nameWithOwner)
export WORKFLOW_NAME=$(gh run view "${WORKFLOW_RUN_ID}" --json workflowName -q .workflowName)

# Run alloy in the background and save its PID
alloy run /etc/alloy/upload-logs.alloy \
  --storage.path "/tmp/alloy" \
  --stability.level experimental \
  --disable-reporting &
ALLOY_PID=$!

# Set timeout duration (5 minutes = 300 seconds)
UPLOAD_TIMEOUT=${UPLOAD_TIMEOUT:-300}
START_TIME=$SECONDS

# Watch for workflow_logs.json to be deleted or timeout
while true; do
  # Check if timeout reached
  if [ $((SECONDS - START_TIME)) -ge "${UPLOAD_TIMEOUT}" ]; then
    echo "Timeout reached after ${UPLOAD_TIMEOUT} seconds. Killing Alloy process."
    kill $ALLOY_PID || true
    exit 1
  fi

  # Check if log directory is empty
  if [ -z "$(ls -A "${LOG_DIRECTORY}")" ]; then
    kill $ALLOY_PID || true
    break
  fi
done
