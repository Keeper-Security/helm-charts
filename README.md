# Keeper Security Helm Charts

Official Helm charts for deploying Keeper Security products on Kubernetes.

## Charts

| Chart | Description | Version |
|-------|-------------|---------|
| [keeper-injector](charts/keeper-injector/) | Keeper Secrets Manager Kubernetes Injector | 0.10.0 |
| [keeper-gateway](charts/keeper-gateway/) | Keeper PAM Gateway | 0.1.3 |

## Usage

### OCI Registry (Docker Hub)

```bash
helm install keeper-injector oci://registry-1.docker.io/keeper/keeper-injector \
  --namespace keeper-security \
  --create-namespace
```

### Helm Repository

```bash
helm repo add keeper https://keeper-security.github.io/helm-charts
helm repo update
helm install keeper-injector keeper/keeper-injector \
  --namespace keeper-security \
  --create-namespace
```

## Contributing

Each chart has its own README with detailed configuration options. See the chart directory for more information.

### Adding a New Chart

1. Create a new directory under `charts/`
2. Follow the standard Helm chart structure
3. Include a `Chart.yaml`, `values.yaml`, and `README.md`
4. The release workflow will automatically detect and publish new charts

## Release Process

Charts are released automatically when changes are pushed to `main`:

1. The CI workflow detects which charts have version changes
2. Changed charts are packaged and pushed to Docker Hub OCI registry
3. The GitHub Pages Helm repository index is updated
4. ArtifactHub syncs automatically from GitHub Pages

## Links

- [Keeper Security](https://www.keepersecurity.com)
- [Keeper Secrets Manager](https://www.keepersecurity.com/secrets-manager.html)
- [ArtifactHub](https://artifacthub.io/packages/search?repo=keeper-security)

## License

MIT License - [Keeper Security, Inc.](https://www.keepersecurity.com)
