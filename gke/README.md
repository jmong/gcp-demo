# gke

## Requirements

You will need:
* `gcloud` command tool
* `docker` command tool
* `kubectl` command tool
* `git` command tool

## Demos

### run-canary.sh

Spins up a Kubernetes cluster with mulitple deployments and pods.

It also does a blue/green deployment.

### run-secrets.sh

Creates a Kubernetes secret, and encrypts/decrypts a message using the secret.

### run-statefulsets.sh

Spins up a MongoDB service as a Kubernetes Statefulset.

## References

* https://cloud.google.com/kubernetes-engine/docs/quickstart
* https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials
