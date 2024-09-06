#!/usr/bin/env bash

set -xe

TEST_NAMESPACE="${TEST_NAMESPACE:-k8s-test}"
RELEASE_NAME="${RELEASE_NAME:-cryostat-k8s-test}"

if [ "${CREATE_CLUSTER:-true}" = "true" ]; then
    kind create cluster
fi

kubectl create ns "${TEST_NAMESPACE}"
function cleanup() {
    kubectl delete ns "${TEST_NAMESPACE}"
    if [ "${CREATE_CLUSTER:-true}" = "true" ]; then
        kind delete cluster
    fi
}
trap cleanup EXIT

helm install --namespace "${TEST_NAMESPACE}" "${RELEASE_NAME}" ./charts/cryostat
sleep "${SLEEP_DELAY:-60}"
helm test --namespace "${TEST_NAMESPACE}" "${RELEASE_NAME}"
