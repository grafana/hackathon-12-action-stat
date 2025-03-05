#!/bin/bash


echo "Action Stat!"
echo "Version: $(cat /version)"

export LOG_DIRECTORY="/var/logs/action"
mkdir -p ${LOG_DIRECTORY}

WORKFLOW_NAME=$(gh run view "${WORKFLOW_RUN_ID}" --json workflowName -q .workflowName)
GITHUB_REPOSITORY=$(gh repo view --json nameWithOwner -q .nameWithOwner)

echo "Getting logs for workflow run ${WORKFLOW_RUN_ID} on ${GITHUB_REPOSITORY} for workflow ${WORKFLOW_NAME}"

gh auth status

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
