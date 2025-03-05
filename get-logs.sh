#!/bin/bash
# Fail on error and unbound variables
set -eu

function main() {

  # Ensure GitHub Workflow run ID is set
  if [[ -z "${WORKFLOW_RUN_ID:-}" ]]; then
      echo -e "\033[31mError: GITHUB_RUN_ID must be set.\033[0m"
      exit 1
  fi

  # Ensure Log directory is set
  if [[ -z "${LOG_DIRECTORY:-}" ]]; then
    echo -e "\033[31mError: LOG_DIRECTORY must be set.\033[0m"
    exit 1
  fi

  # Ensure GitHub CLI is authenticated
  if ! gh auth status &>/dev/null; then
      echo -e "\033[31mError: GitHub CLI is not authenticated. Ensure GH_TOKEN is set.\033[0m"
      exit 1
  fi

  GITHUB_REPOSITORY=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  WORKFLOW_NAME=$(gh run view "${WORKFLOW_RUN_ID}" --json workflowName -q .workflowName)

  # Fetch jobs and steps ID and name, excluding current job
  echo "Fetching workflow run jobs information..."
  if ! JOBS_JSON=$(gh run view "${WORKFLOW_RUN_ID}" --json jobs --jq '.jobs'); then
      echo -e "\033[31mError fetching workflow jobs\033[0m"
      echo -e "Raw output: ${JOBS_JSON}"
      exit 1
  fi

  # Validate JSON output
  if ! echo "${JOBS_JSON}" | jq empty; then
      echo -e "\033[31mInvalid JSON received from GitHub CLI\033[0m"
      echo -e "Raw output: ${JOBS_JSON}"
      exit 1
  fi

  echo "Processing workflow: ${WORKFLOW_NAME} in ${GITHUB_REPOSITORY}"

  # Get the count of jobs
  JOBS_COUNT=$(echo "${JOBS_JSON}" | jq 'length')
  
  if [[ "${JOBS_COUNT}" -eq 0 ]]; then
      echo "No jobs found in workflow run"
      exit 0
  fi

  # Process each job using indices
  JOB_INDEX=0
  while [[ "${JOB_INDEX}" -lt "${JOBS_COUNT}" ]]; do
    # Extract single JSON-formatted job using index
    JOB_ID=$(echo "${JOBS_JSON}" | jq --arg i "${JOB_INDEX}" -r '.[$i | tonumber].databaseId')
    JOB_NAME=$(echo "${JOBS_JSON}" | jq --arg i "${JOB_INDEX}" -r '.[$i | tonumber].name')
    
    if [[ -z "${JOB_ID}" || "${JOB_ID}" == "null" || -z "${JOB_NAME}" || "${JOB_NAME}" == "null" ]]; then
        echo -e "\033[33mWarning:Invalid job data received for jobs index ${JOB_INDEX}.\033[0m"
        JOB_INDEX=$((JOB_INDEX + 1))
        continue
    fi
    
    echo "Processing job $((JOB_INDEX + 1)) of ${JOBS_COUNT}: ${JOB_NAME} (ID: ${JOB_ID})"

    # Fetch logs for this job
    echo "Fetching job logs..."
    JOB_LOGS=$(gh run view --job "${JOB_ID}" --log)

    echo "Processing job steps..."
    
    # Loop through each step in the job
    STEPS_COUNT=$(echo "${JOBS_JSON}" | jq --arg i "${JOB_INDEX}" -r '.[$i | tonumber].steps | length')
    STEP_INDEX=0

    while [[ "${STEP_INDEX}" -lt "${STEPS_COUNT}" ]]; do
      STEP_NAME=$(echo "${JOBS_JSON}" | jq --arg i "${JOB_INDEX}" --arg j "${STEP_INDEX}" -r '.[$i | tonumber].steps[$j | tonumber].name')
      STEP_NUMBER=$(echo "${JOBS_JSON}" | jq --arg i "${JOB_INDEX}" --arg j "${STEP_INDEX}" -r '.[$i | tonumber].steps[$j | tonumber].number')

      echo "Processing job $((JOB_INDEX + 1)) - step $((STEP_INDEX + 1)) of ${STEPS_COUNT}: ${STEP_NAME}"

      if [[ -z "${STEP_NAME}" || "${STEP_NAME}" == "null" ]]; then
          echo -e "\033[33mWarning: Invalid step data received for step index ${STEP_INDEX}.\033[0m"
          STEP_INDEX=$((STEP_INDEX + 1))
          continue
      fi

      STEP_LOG_PATTERN="${JOB_NAME}\t${STEP_NAME}"
      STEP_LOGS=$(echo "${JOB_LOGS}" | grep "^${STEP_LOG_PATTERN}" || echo "No logs found for ${STEP_LOG_PATTERN}")

      # Write step logs to file
      echo "${STEP_LOGS}" > "${LOG_DIRECTORY}/job-${JOB_ID}-step-${STEP_NUMBER}.log"
          
      STEP_INDEX=$((STEP_INDEX + 1))
    done
            
    JOB_INDEX=$((JOB_INDEX + 1))
  done

  # Print confirmation
  FILE_COUNT=$(find "${LOG_DIRECTORY}" -type f | wc -l) || true
  if [[ "${FILE_COUNT}" -gt 0 ]]; then
    echo "Successfully processed workflow logs: ${FILE_COUNT} files written to ${LOG_DIRECTORY}"
  else
    echo -e "\033[33mWarning: No log files were created in ${LOG_DIRECTORY}\033[0m"
  fi
}

# If the script is being executed directly (not sourced), run main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
