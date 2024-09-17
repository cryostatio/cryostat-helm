#!/usr/bin/env bash

set -xe

if ! command -v ct; then
    echo "ct command not found in \$PATH"
    exit 1
fi

TEST_NAMESPACE="${TEST_NAMESPACE:-helm-test}"
CLUSTER_CLIENT="${CLUSTER_CLIENT:-$(which kubectl)}"

if ! command -v "${CLUSTER_CLIENT}"; then
    echo "${CLUSTER_CLIENT} command not found in \$PATH"
    exit 1
fi

function cleanup() {
    "${CLUSTER_CLIENT}" delete ns "${TEST_NAMESPACE}"
}
trap cleanup EXIT

"${CLUSTER_CLIENT}" create ns "${TEST_NAMESPACE}"
ct install --remote "${REMOTE:-origin}" --target-branch "${TARGET_BRANCH:-main}" --namespace="${TEST_NAMESPACE}" --config ct.yaml --debug "$@"
