# Vendored Garage Helm chart

Upstream publishes this chart only inside the Garage repository, not in a Helm index, so a pinned copy lives here.

- Source: https://git.deuxfleurs.fr/Deuxfleurs/garage, path `script/helm/garage`
- Tag: `v2.4.1` (commit `268334bd2530fa99f8b06c7383b2e9f776691edd`), chart version 0.10.2
- Local change: the chart's `tests/` directory (Helm test hooks) was dropped. Everything else is unmodified.

To upgrade, replace this directory with the new tag's copy, keep the Garage version in step with `docker-compose.yml` in the app repo, and update this file.
