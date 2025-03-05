#!/bin/bash

set -euo pipefail

echo "Action Stat!"
echo "Version: $(cat /version)"

git config --global --add safe.directory "${GITHUB_WORKSPACE}"
cd "${GITHUB_WORKSPACE}"

export LOG_DIRECTORY="/var/logs/action"
mkdir -p ${LOG_DIRECTORY}

/etc/bin/get-logs.sh

# # Run alloy in the background and save its PID
# alloy run /etc/alloy/upload-logs.alloy --stability.level public-preview --disable-reporting &
# ALLOY_PID=$!

# # Set timeout duration (5 minutes = 300 seconds)
# TIMEOUT=300
# START_TIME=$SECONDS

# # Watch for workflow_logs.json to be deleted or timeout
# while true; do
#   # Check if timeout reached
#   if [ $((SECONDS - START_TIME)) -ge $TIMEOUT ]; then
#     echo "Timeout reached after ${TIMEOUT} seconds. Killing alloy process."
#     kill $ALLOY_PID || true
#     return 1
#   fi

#   # Check if log directory is empty
#   if [ -z "$(ls -A "${LOG_DIRECTORY}")" ]; then
#     kill $ALLOY_PID || true
#     break
#   fi
# done
