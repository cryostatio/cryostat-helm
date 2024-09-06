#!/usr/bin/env bash

set -xe

TEST_NAMESPACE="${TEST_NAMESPACE:-helm-test}"

function cleanup() {
    kubectl delete ns "${TEST_NAMESPACE}"
}
trap cleanup EXIT

kubectl create ns "${TEST_NAMESPACE}"
ct install --remote "${REMOTE:-origin}" --target-branch "${TARGET_BRANCH:-main}" --namespace="${TEST_NAMESPACE}" --config ct.yaml --debug "$@"
