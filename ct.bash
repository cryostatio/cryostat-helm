#!/usr/bin/env bash

set -xe

TEST_NAMESPACE="${TEST_NAMESPACE:-helm-test}"
CLUSTER_CLIENT="${CLUSTER_CLIENT:-$(which kubectl)}"

function cleanup() {
    "${CLUSTER_CLIENT}" delete ns "${TEST_NAMESPACE}"
}
trap cleanup EXIT

"${CLUSTER_CLIENT}" create ns "${TEST_NAMESPACE}"
ct install --remote "${REMOTE:-origin}" --target-branch "${TARGET_BRANCH:-main}" --namespace="${TEST_NAMESPACE}" --config ct.yaml --debug "$@"
