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

# Create metrics directory if it doesn't exist
mkdir -p "${METRICS_DIRECTORY}"

# Collect workflow run data
echo "Collecting metrics for workflow run ${WORKFLOW_RUN_ID}..."
gh run view "${WORKFLOW_RUN_ID}" \
    --json attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,jobs,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName \
    > "${METRICS_DIRECTORY}/workflow-${WORKFLOW_RUN_ID}.json"

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
                    (fromdateiso8601(.updatedAt) - fromdateiso8601(.createdAt))
                elif .startedAt != null then
                    (fromdateiso8601($now) - fromdateiso8601(.startedAt))
                else
                    0
                end
            ),
            jobs: (
                .jobs | map(
                    . + {
                        duration: (
                            if .completed_at != null then
                                (fromdateiso8601(.completed_at) - fromdateiso8601(.started_at))
                            elif .started_at != null then
                                (fromdateiso8601($now) - fromdateiso8601(.started_at))
                            else
                                0
                            end
                        ),
                        steps: (
                            .steps | map(
                                . + {
                                    duration: (
                                        if .completed_at != null then
                                            (fromdateiso8601(.completed_at) - fromdateiso8601(.started_at))
                                        elif .started_at != null then
                                            (fromdateiso8601($now) - fromdateiso8601(.started_at))
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

echo "Metrics collected and saved to ${METRICS_DIRECTORY}/workflow-${WORKFLOW_RUN_ID}.json" 
