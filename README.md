# VGU Graduation deployment

GitOps configuration for the `vgu-graduation` home k3s cluster.

This repository is intentionally separate from application source. The application repository builds and publishes images; this repository owns the desired cluster state, environment configuration, and SOPS-encrypted Kubernetes Secrets.

## Repository layout

```text
clusters/home/                 Flux bootstrap and reconciliation order
infrastructure/controllers/   Cluster-wide Helm controllers/operators
infrastructure/configs/        Namespaces and cluster policies
workloads/home/                Home-cluster application overlay
```

The repository currently deploys PostgreSQL and the API workload. The API uses
the `fuisl/grad26-api:latest` image and is exposed inside the `grad` namespace
as the `api-service` ClusterIP Service on port 4000. Worker, web, Garage, translation,
and printer workloads are not enabled.

Application local-development and deployment boundaries are documented in
[`docs/application-deployment.md`](docs/application-deployment.md). In short,
the application repository's Compose file currently provides PostgreSQL for
local development; it is not yet a complete production deployment.

## Bootstrap

From the k3s server, after installing the Flux CLI and configuring kubeconfig:

```sh
flux check --pre

flux bootstrap github \
  --owner=fuisloy \
  --repository=vgu-graduation-deployment \
  --branch=main \
  --path=clusters/home \
  --personal
```

Flux will add `clusters/home/flux-system/`. Do not create that directory manually.

## SOPS

Replace the placeholder recipient in `.sops.yaml` with the public recipient from the dedicated home-cluster age key before adding any `*.sops.yaml` files. Never commit the age private key.

Create the Flux decryption Secret out of band before adding encrypted resources:

```sh
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=/path/to/home.agekey
```

After the Secret exists, add this block to each Flux `Kustomization` that contains SOPS-encrypted resources:

```yaml
decryption:
  provider: sops
  secretRef:
    name: sops-age
```

## Reconciliation order

```text
Flux bootstrap → infrastructure controllers → infrastructure config → home workloads
```

Additional workloads should be separate Flux `Kustomization` objects so
experimental and venue-only components can be suspended independently.

## Safety rules

- Do not commit tokens, kubeconfigs, age private keys, or plaintext Secret data.
- Pin Helm chart versions and application image digests before production use.
- Keep PostgreSQL, Garage, inference, and printer services without public Ingresses.
- Validate manifests with `kustomize build` and `flux diff kustomization` before reconciliation.
- Keep the home cluster and data backups recoverable independently of this repository.
