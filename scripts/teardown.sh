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
ISTIO_DIR="$ROOT/istio-${ISTIO_VERSION}"

kubectl delete ns vm --ignore-not-found=true
kubectl delete ns bookinfo --ignore-not-found=true

# Uninstall the ILBs installed for mesh expansion
kubectl delete -f "$ISTIO_DIR/install/kubernetes/mesh-expansion.yaml" --ignore-not-found=true

# Finished deleting resources from GKE cluster

# Wait for Kubernetes resources to be deleted before deleting the cluster
# Also, filter out the resources to what would specifically be created for
# the GKE cluster
until [[ $(gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules list --format yaml \
              --filter "description ~ istio-system.*ilb OR description:kube-system/dns-ilb") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

until [[ $(gcloud --project="${ISTIO_PROJECT}" compute firewall-rules list --format yaml \
             --filter "(name:node-hc AND targetTags.list():gke-${ISTIO_CLUSTER}) OR description ~ istio-system.*ilb OR description:kube-system/dns-ilb")  == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

# delete a couple of firewall rules manually due to this bug:
# https://issuetracker.google.com/issues/126775279
# TODO: remove line below when bug is solved
gcloud --project="${ISTIO_PROJECT}" compute firewall-rules delete \
  $(gcloud --project="${ISTIO_PROJECT}" compute firewall-rules list --format "value(name)" \
  --filter "(name:node-http-hc OR name:k8s-fw) AND targetTags.list():gke-${ISTIO_CLUSTER}") --quiet
# Wait for the firewall rules to delete
until [[ $(gcloud --project="${ISTIO_PROJECT}" compute firewall-rules list --format "value(name)" \
  --filter "(name:node-http-hc OR name:k8s-fw) AND targetTags.list():gke-${ISTIO_CLUSTER}") == "" ]]; do
  echo "Waiting for firewall rules to delete..."
  sleep 10
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
