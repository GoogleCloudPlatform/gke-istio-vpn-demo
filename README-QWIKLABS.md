# Istio on Kubernetes Engine and Compute Engine

## Table of Contents
<!--toc-->
  * [Introduction](#introduction)
     * [Istio on GKE](#istio-on-gke)
  * [Architecture](#architecture)
     * [Application architecture](#application-architecture)
     * [Infrastructure architecture](#infrastructure-architecture)
  * [Run Demo using Cloud Shell](#run-demo-using-cloud-shell)
  * [Configure gcloud](#configure-gcloud)
  * [Creating a project](#creating-a-project)
  * [Deployment](#deployment)
     * [Noteworthy Aspects of the Deployment:](#noteworthy-aspects-of-the-deployment)
  * [Validation](#validation)
  * [Tear Down](#tear-down)
  * [Troubleshooting](#troubleshooting)
  * [Relevant Material](#relevant-material)
<!--toc-->

## Introduction

[Istio](https://istio.io/) is part of a new category of products known as "service mesh" software
designed to manage the complexity of service resilience in a microservice
infrastructure. It defines itself as a service management framework built to
keep business logic separate from the logic to keep your services up and
running. In other words, it provides a layer on top of the network that will
automatically route traffic to the appropriate services, handle [circuit
breaker](https://en.wikipedia.org/wiki/Circuit_breaker_design_pattern) logic,
enforce access and load balancing policies, and generate telemetry data to
gain insight into the network and allow for quick diagnosis of issues.

Istio makes it easy to create a network of deployed services with load balancing, service-to-service authentication and monitoring without any changes in service code.

Core features of Istio include:

1. [Traffic management](https://istio.io/docs/concepts/traffic-management/) - Istio simplifies configuration of service-level properties like circuit breakers, timeouts, and retries making the network more robust.
2. [Security](https://istio.io/docs/concepts/security/) - Istio, using with Kubernetes (or infrastructure) network policies, provides the ability to secure pod-to-pod or service-to-service communication at the network and application layers.
3. Platform support - Istio is platform-independent and currently supports service deployment on Kubernetes, services registered with Consul and services running on individual virtual machines.
5. Integration and customization - Istio, has a policy enforcement component which can be extended and customized to integrate with existing solutions for ACLs, logging, monitoring, quotas and auditing.

For more information on Istio, please refer to the [Istio
documentation](https://istio.io/docs/).

### Istio on GKE

When you create or update the cluster with Istio on GKE, following components are installed:

1. Pilot, which is responsible for service discovery and for configuring the Envoy sidecar proxies in an Istio service mesh.
2. [Istio-Policy and Istio-Telemetry](https://istio.io/docs/concepts/policies-and-telemetry), which enforce usage policies and gather telemetry data.
3. The [Istio Ingress gateway](https://istio.io/docs/tasks/traffic-management/ingress), which provides an ingress point for traffic from outside the cluster.
4. The [Istio Egress gateway](https://istio.io/docs/tasks/traffic-management/egress), which allow Istio features like monitoring and routing rules to be applied to traffic exiting the mesh.
5. [Citadel](https://istio.io/docs/concepts/security), which automates key and certificate management for Istio.
6. [Galley](https://istio.io/docs/concepts/what-is-istio/#galley), which provides configuration management services for Istio.

For more information on how to install Istio, please refer to the [Installing Istio on GKE](https://cloud.google.com/istio/docs/istio-on-gke/installing).

This repository contains demonstration code for Istio's mesh expansion feature
between resources in two Google Cloud Platform (GCP) projects connected via
VPN. The feature allows for a non-Kubernetes service running outside of the
Istio infrastructure on Kubernetes Engine to be integrated into and managed by
the Istio service mesh.

## Architecture

This demonstration will create a number of resources.

* A single (GKE) cluster with IP aliasing turned on in a custom network in
  project A
* A Google Compute Engine (GCE) instance in a custom network project B
* A VPN bridging the two networks containing the GKE cluster and the GCE
  instance
* The Istio service mesh installed in the GKE cluster
* The [BookInfo](https://istio.io/docs/examples/bookinfo/) application installed in the Istio service mesh
* A firewall rule allowing full SSH access to the GCE instance from any IP
  address
* A firewall rule allowing full access to the MySQL database from the GKE
  cluster

### Application architecture

![](./images/bookinfo.png)

### Infrastructure architecture

![](./images/istio-gke-gce-vpn.png)

## Run Demo using Cloud Shell

Use the `--recursive` argument to download dependencies provided via a git submodule.

```shell
git submodule update --init --recursive

## Configure gcloud

When using Cloud Shell execute the following command in order to setup gcloud cli. When executing this command please setup your region and zone.

```console
gcloud init
```

## Creating a project
In order to complete this demo, two projects need to exist, one for the GKE
cluster and a second for the GCE instance, which will be connected via a VPN.

To create projects:
1. Log in to the [GCP Console](http://console.cloud.google.com/)
1. Click on `Select a project` in the top navigating bar
1. Click on `New Project` in on the top right of the window:

  ![](./images/new_project.png)

1. Enter a project name, and note the project id below it.
(in this case, the project id is `angelic-phoenix-210818`):

  ![](./images/new-project-name.png)

## Deployment

Open the `scripts/istio.env` file and set:

  * `ISTIO_PROJECT` to the ID of the project you want to use for Istio infrastructure
  * `GCE_PROJECT` to the ID of the project you want to use for GCE
  * Any variables you wish to customize

Note that the ID of the project is not always the same as the name. Also, please note that when setting `ISTIO_PROJECT` and `GCE_PROJECT` they should be uncommented. Failure to do so will result in an error in the following step.

Once configuration is complete the demo cluster and app can be deployed.:

```shell
make create
```

This make target calls the `scripts/create.sh` script which will use Terraform to automatically build out necessary infrastructure, including a Kubernetes cluster, and will then use `kubectl` to deploy application components and other resource to the cluster.

### Noteworthy Aspects of the Deployment:

1. The GKE cluster uses IP aliasing, without this feature, the demo would not
work. IP Aliasing is a feature by which services and pods can have their IP
addresses set to values within a specific CIDR block, which allows them to be
known in advance of a deployment, and callable by other resources. This also
ensures that the IP addresses will not conflict with other GCP resources and
provides an additional mechanism for firewall traffic control (e.g. rules on the
pod may differ from those on the underlying host).
For more information on IP Aliasing see:
https://cloud.google.com/kubernetes-engine/docs/how-to/alias-ips

1. The GKE cluster's IP CIDR blocks are defined in the `istio.env` file and can
be changed in the event that other values are needed (e.g. if they conflict with
other IP address space).

1. Firewall and Routing rules are created at deployment time to facilitate the
necessary communication without exposing ports and services unnecessarily.

1. The VPN configuration (endpoints, firewalls and routing rules) are defined in
the included terraform configuration, `terraform/main.tf`. For more information on VPNs
see: https://cloud.google.com/vpn/docs/how-to

## Validation

To validate that everything is working correctly, first open your browser to
the URL provided at the end of the installation script.
You'll see a URL for the BookInfo web site. After taking a look, run:

```shell
make validate
```

This will change the rating between 1 and 5 stars for Reviewer1.

Refresh the page in your browser; the first rating should reflect the
number of stars passed to the validate script. Behind the scenes, the validate
script is directly editing the database on the GCE VM that was integrated into
the mesh, proving that the BookInfo application is using the database on the VM
as the source of the rating data.

## Tear Down

To shutdown the demo run:

```shell
make teardown
```

This will destroy all the resources created by Terraform including everything deployed to the Kubernetes cluster.

## Troubleshooting

**Problem:** The Book Reviews section is returning an error stating that the ratings service is not available.

**Solution:** Istio may still be configuring the mesh. Wait for a minute so while refreshing the page.

----

**Problem:** The install script fails with a `Permission denied` when running Terraform.

**Solution:** The credentials that Terraform is using do not provide the necessary permissions to create resources in the selected projects. Ensure that the account listed in `gcloud config list` has necessary permissions to create resources. If it does, regenerate the application default credentials using `gcloud auth application-default login`.

----

**Problem:** Loss of GKE cluster network connectivity after 24 hours

**Solution:** Remove the GCE instance and rerun all steps involving the GCE setup

----

**Problem:** The install script times out while waiting for the internal load balancers to finish provisioning.

**Solution:** Likely the cause is a transient platform issue. Rerun the script as it is idempotent up to this point and should not run into any issues with infrastructure that already exists.

----

**Problem:** The install script gives an error like:

>ERROR: (gcloud.services.enable) User [{your-email address}] does not have permission to access service [compute.googleapis.com:enable] (or it may not exist): Project '{your-project-name}' not found or permission denied.

**Solution:** Enter the project Id and not the project name into `scripts/istio.env`

## Relevant Material

* https://github.com/istio/community
* https://istio.io/docs/guides/bookinfo.html
* https://cloud.google.com/kubernetes-engine/docs/tutorials/istio-on-gke
* https://cloud.google.com/compute/docs/tutorials/istio-on-compute-engine
* https://istio.io/docs/setup/kubernetes/mesh-expansion.html
* https://istio.io/docs/guides/integrating-vms.html


**This is not an officially supported Google product**
