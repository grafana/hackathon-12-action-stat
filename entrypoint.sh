#!/bin/bash

echo "Hello, world!"
mkdir -p /var/logs/action

export GH_TOKEN=${INPUT_GITHUB_TOKEN}

echo "Getting logs for workflow run ${INPUT_WORKFLOW_RUN_ID} on ${INPUT_REPOSITORY} for workflow ${INPUT_WORKFLOW_NAME}"
gh auth status

