#! /usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -x

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# shellcheck source=scripts/istio.env
source "$ROOT/scripts/istio.env"
#ISTIO_DIR="$ROOT/istio-${ISTIO_VERSION}"

kubectl delete ns vm --ignore-not-found=true
kubectl delete ns bookinfo --ignore-not-found=true

# Disable the Istio GKE Addon to prevent it from automatically
# recreating Istio services which create load balancers and
# firewall rules which would block a successful TF destroy.
gcloud beta container clusters update "${ISTIO_CLUSTER}" \
  --project "${ISTIO_PROJECT}" --zone="${ZONE}" \
  --update-addons=Istio=DISABLED

# Pause build for debugging
touch pausefile
until [ ! -f pausefile ]; do
  echo "waiting until pausefile is removed to proceed"
  sleep 10
done

# Delete the dns-ilb service explicitly since it is left over.
kubectl delete svc -n kube-system dns-ilb --ignore-not-found=true

# Find all internal (ILB) forwarding rules in the network: istio-network
FWDING_RULE_NAMES="$(gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules list \
  --format="value(name)"  \
  --filter "(description ~ istio-system.*ilb OR description:kube-system/dns-ilb) AND network ~ /istio-network$")"
# Iterate and delete the forwarding rule by name and its corresponding backend-service by the same name
for FWD_RULE in ${FWDING_RULE_NAMES}; do
  gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules delete "${FWD_RULE}" --region="${REGION}" || true
  gcloud --project="${ISTIO_PROJECT}" compute backend-services delete "${FWD_RULE}" --region="${REGION}" || true
done

# Find all target pools with this cluster as the target by name
TARGET_POOLS="$(gcloud --project="${ISTIO_PROJECT}" compute target-pools list --format="value(name)" --filter="(instances ~ gke-${ISTIO_CLUSTER})")"
# Find all health checks with this cluster's nodes as the instances
HEALTH_CHECKS="$(gcloud --project="${ISTIO_PROJECT}" compute target-pools list --format="value(healthChecks)" --filter="(instances ~ gke-${ISTIO_CLUSTER})" | sed 's/.*\/\(k8s\-.*$\)/\1/g')"
# Delete the external (RLB) forwarding rules by name and the target pool by the same name
for TARGET_POOL in ${TARGET_POOLS}; do
  gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules delete "${TARGET_POOL}" --region="${REGION}"
  gcloud --project="${ISTIO_PROJECT}" compute target-pools delete "${TARGET_POOL}" --region="${REGION}"
done
# Delete the leftover health check by name
for HEALTH_CHECK in ${HEALTH_CHECKS}; do
  gcloud --project="${ISTIO_PROJECT}" compute health-checks delete "${HEALTH_CHECK}"
done

# Delete all the firewall rules that aren't named like our cluster name which
# correspond to our health checks and load balancers that are dynamically created.
# This is because GKE manages those named with the cluster name get cleaned
# up with a terraform destroy.
FW_RULES="$(gcloud --project="${ISTIO_PROJECT}" compute firewall-rules list --format "value(name)"   --filter "targetTags.list():gke-${ISTIO_CLUSTER} AND NOT name ~ gke-${ISTIO_CLUSTER}")"
for FW_RULE in ${FW_RULES}; do
  gcloud --project="${ISTIO_PROJECT}" compute firewall-rules delete "${FW_RULE}"
done

# Tear down all of the infrastructure created by Terraform
(cd "$ROOT/terraform"; terraform init; terraform destroy -input=false -auto-approve\
  -var "istio_project=${ISTIO_PROJECT}" \
  -var "gce_project=${GCE_PROJECT}" \
  -var "istio_cluster=${ISTIO_CLUSTER}" \
  -var "zone=${ZONE}" \
  -var "region=${REGION}" \
  -var "gce_network=${GCE_NETWORK}" \
  -var "gce_subnet=${GCE_SUBNET}" \
  -var "gce_subnet_cidr=${GCE_SUBNET_CIDR}" \
  -var "istio_network=${ISTIO_NETWORK}" \
  -var "istio_subnet=${ISTIO_SUBNET}" \
  -var "istio_subnet_cidr=${ISTIO_SUBNET_CIDR}" \
  -var "istio_subnet_cluster_cidr=${ISTIO_SUBNET_CLUSTER_CIDR}" \
  -var "istio_subnet_services_cidr=${ISTIO_SUBNET_SERVICES_CIDR}" \
  -var "gke_version=${GKE_VERSION}" \
  -var "gce_vm=${GCE_VM}")

# Clean up the downloaded Istio components
if [[ -d "$ROOT/istio-$ISTIO_VERSION" ]]; then
  rm -rf istio-$ISTIO_VERSION
fi
