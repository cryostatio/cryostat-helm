#!/usr/bin/env bash

set -xe

CLUSTER_CLIENT="${CLUSTER_CLIENT:-$(which kubectl)}"

if ! command -v "${CLUSTER_CLIENT}"; then
    echo "${CLUSTER_CLIENT} command not found in \$PATH"
    exit 1
fi

if ! command -v helm; then
    echo "No 'helm' found in \$PATH"
    exit 1
fi

TEST_NAMESPACE="${TEST_NAMESPACE:-k8s-test}"
RELEASE_NAME="${RELEASE_NAME:-cryostat-k8s-test}"

if [ "${CREATE_CLUSTER:-true}" = "true" ]; then
    if ! command -v kind; then
        echo "No 'kind' found in \$PATH"
        exit 1
    fi
    kind create cluster
fi

"${CLUSTER_CLIENT}" create ns "${TEST_NAMESPACE}"
function cleanup() {
    "${CLUSTER_CLIENT}" delete ns "${TEST_NAMESPACE}"
    if [ "${CREATE_CLUSTER:-true}" = "true" ]; then
        kind delete cluster
    fi
}
trap cleanup EXIT

helm install --namespace "${TEST_NAMESPACE}" "${RELEASE_NAME}" ./charts/cryostat
"${CLUSTER_CLIENT}" wait --timeout=2m --for=condition=Available=true --namespace "${TEST_NAMESPACE}" deployment -l app.kubernetes.io/name=cryostat
"${CLUSTER_CLIENT}" wait --timeout=2m --for=condition=Ready=true --namespace "${TEST_NAMESPACE}" pod -l app.kubernetes.io/name=cryostat
helm test --namespace "${TEST_NAMESPACE}" "${RELEASE_NAME}"
