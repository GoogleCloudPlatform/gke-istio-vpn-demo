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

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# shellcheck source=scripts/istio.env
source "$ROOT/scripts/istio.env"

kubectl delete deploy,svc --all -n default
kubectl delete deploy,svc --all -n istio-system
kubectl delete deploy,svc --all -n vm
kubectl delete svc dns-ilb -n kube-system --ignore-not-found=true

# Finished deleting resources from GKE cluster

# Wait for Kubernetes resources to be deleted before deleting the cluster
# Also, filter out the resources to what would specifically be created for
# the GKE cluster
until [[ $(gcloud --project="${ISTIO_PROJECT}" compute target-pools list \
              --format="value(name)" \
              --filter="instances[]:gke-${ISTIO_CLUSTER}") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

until [[ $(gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules list --format yaml \
              --filter "description:istio-system OR description:kube-system/dns-ilb") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

until [[ $(gcloud --project="${ISTIO_PROJECT}" compute firewall-rules list \
             --filter "name:k8s AND targetTags.list():gke-${ISTIO_CLUSTER}" \
             --format "value(name)") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

# Tear down all of the infrastructure created by Terraform
(cd "$ROOT/terraform"; terraform destroy -input=false -auto-approve\
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
  -var "gce_vm=${GCE_VM}")

# Clean up the downloaded Istio components
if [[ -d "$ROOT/istio-$ISTIO_VERSION" ]]; then
  rm -rf istio-$ISTIO_VERSION
fi
