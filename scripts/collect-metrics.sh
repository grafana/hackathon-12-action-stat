#!/bin/bash
set -euo pipefail

# Ensure required environment variables are set
if [[ -z "${WORKFLOW_RUN_ID:-}" ]]; then
    echo "Error: WORKFLOW_RUN_ID environment variable is not set"
    exit 1
fi

if [[ -z "${METRICS_DIRECTORY:-}" ]]; then
    echo "Error: METRICS_DIRECTORY environment variable is not set"
    exit 1
fi

WORKFLOW_NAME=$(gh run view "${WORKFLOW_RUN_ID}" --json workflowName -q .workflowName)

# Create metrics directory if it doesn't exist
mkdir -p "${METRICS_DIRECTORY}"

# Collect workflow run data
echo "Collecting metrics for workflow run ${WORKFLOW_RUN_ID}..."
gh run view "${WORKFLOW_RUN_ID}" \
    --json attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,jobs,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName \
    > "${METRICS_DIRECTORY}/workflow-${WORKFLOW_RUN_ID}.json"

# Validate the JSON output
echo "Validating JSON output..."
if ! jq empty "${METRICS_DIRECTORY}/workflow-${WORKFLOW_RUN_ID}.json" 2>/dev/null; then
    echo "Error: Invalid JSON received from GitHub CLI"
    echo "Raw content sample (first 500 chars):"
    head -c 500 "${METRICS_DIRECTORY}/workflow-${WORKFLOW_RUN_ID}.json"
    exit 1
fi
echo "JSON validation successful."

# Calculate duration and add it to the JSON
if command -v jq >/dev/null 2>&1; then
    # Use jq to calculate duration if available
    temp_file=$(mktemp) || { echo "Error: Failed to create temporary file"; exit 1; }
    current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Process the JSON and save to temp file
    if ! jq --arg now "${current_time}" '
        . + {
            duration: (
                if .updatedAt != null then
                    ((.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) - (.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
                elif .startedAt != null then
                    (($now | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) - (.startedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
                else
                    0
                end
            ),
            jobs: (
                .jobs | map(
                    . + {
                        duration: (
                            if .completed_at != null then
                                ((.completed_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) - (.started_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
                            elif .started_at != null then
                                (($now | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) - (.started_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
                            else
                                0
                            end
                        ),
                        steps: (
                            .steps | map(
                                . + {
                                    duration: (
                                        if .completed_at != null then
                                            ((.completed_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) - (.started_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
                                        elif .started_at != null then
                                            (($now | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) - (.started_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
                                        else
                                            0
                                        end
                                    )
                                }
                            )
                        )
                    }
                )
            )
        }
    ' "${METRICS_DIRECTORY}/workflow-${WORKFLOW_RUN_ID}.json" > "${temp_file}"; then
        echo "Error: Failed to process JSON with jq"
        rm -f "${temp_file}"
        exit 1
    fi

    # Move temp file to final location
    if ! mv "${temp_file}" "${METRICS_DIRECTORY}/workflow-${WORKFLOW_RUN_ID}.json"; then
        echo "Error: Failed to move temporary file to final location"
        rm -f "${temp_file}"
        exit 1
    fi
fi

  # Print confirmation
  echo "Workflow Name: ${WORKFLOW_NAME}"
  echo "Workflow Run ID: ${WORKFLOW_RUN_ID}"
  METRICS_FILE_COUNT=$(find "${METRICS_DIRECTORY}" -type f | wc -l) || true
  if [[ "${METRICS_FILE_COUNT}" -gt 0 ]]; then
    echo "Successfully processed workflow metrics: ${METRICS_FILE_COUNT} file(s) written to ${METRICS_DIRECTORY}"
  else
    echo -e "\033[33mWarning: No log files were created in ${METRICS_DIRECTORY}\033[0m"
  fi
