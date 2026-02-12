# Keeper Secrets Manager Kubernetes Injector

Automatically inject secrets from [Keeper Secrets Manager](https://www.keepersecurity.com/secrets-manager.html) into your Kubernetes pods at runtime using a mutating admission webhook.

## Features

- **No Kubernetes Secrets created** - Secrets are written directly to pod tmpfs (memory-only)
- **Pod-scoped lifetime** - Secrets are removed when pod terminates
- **Automatic rotation** - Sidecar refreshes secrets without pod restarts
- **Simple configuration** - Just two annotations to get started
- **Title-based lookup** - Reference secrets by name, not UIDs
- **Keeper Notation** - Use `keeper://UID/field/password` for precise extraction
- **File Attachments** - Download files from Keeper records
- **Folder Support** - Fetch all secrets from a Keeper folder
- **Production-ready** - HA, metrics, leader election

## Installation

### Quick Install

```bash
helm upgrade --install keeper-injector oci://registry-1.docker.io/keeper/keeper-injector \
  --namespace keeper-security \
  --create-namespace
```

### From Helm Repository

```bash
helm repo add keeper https://keeper-security.github.io/helm-charts
helm upgrade --install keeper-injector keeper/keeper-injector \
  --namespace keeper-security \
  --create-namespace
```

### With Custom Values

```bash
helm upgrade --install keeper-injector oci://registry-1.docker.io/keeper/keeper-injector \
  --namespace keeper-security \
  --create-namespace \
  --set replicaCount=3 \
  --set metrics.enabled=true
```

## Quick Start

### 1. Create KSM Auth Secret

```bash
kubectl create secret generic keeper-credentials \
  --from-file=config=ksm-config.json \
  --namespace default
```

### 2. Annotate Your Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    keeper.security/inject: "true"
    keeper.security/auth-secret: "keeper-credentials"
    keeper.security/secret: "database-credentials"
spec:
  containers:
    - name: app
      image: my-app:latest
```

Secrets will be available at `/keeper/secrets/database-credentials.json`.

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of webhook replicas | `2` |
| `image.repository` | Webhook image | `keeper/injector-webhook` |
| `image.tag` | Image tag | Chart appVersion |
| `sidecar.image.repository` | Sidecar image | `keeper/injector-sidecar` |
| `sidecar.image.tag` | Sidecar image tag | Chart appVersion |
| `metrics.enabled` | Enable Prometheus metrics | `true` |
| `tls.autoGenerate` | Auto-generate TLS certificates | `true` |
| `tls.certManager.enabled` | Use cert-manager (optional) | `false` |

### Full Configuration

See [values.yaml](https://github.com/Keeper-Security/keeper-k8s-injector/blob/main/charts/keeper-injector/values.yaml) for all options.

## Common Annotations

| Annotation | Description | Example |
|------------|-------------|---------|
| `keeper.security/inject` | Enable injection | `"true"` |
| `keeper.security/auth-secret` | K8s secret with KSM config | `"keeper-credentials"` |
| `keeper.security/secret` | Secret title in Keeper | `"my-secret"` |
| `keeper.security/secrets` | Multiple secrets (comma-separated) | `"db-creds, api-keys"` |
| `keeper.security/refresh-interval` | Rotation interval | `"5m"` |
| `keeper.security/signal` | Signal on refresh | `"SIGHUP"` |

[Full annotation reference](https://github.com/Keeper-Security/keeper-k8s-injector/blob/main/docs/annotations.md)

## Examples

Try these working examples:

- [Hello Secrets](https://github.com/Keeper-Security/keeper-k8s-injector/tree/main/examples/01-hello-secrets) - Web page demo (5 min)
- [PostgreSQL](https://github.com/Keeper-Security/keeper-k8s-injector/tree/main/examples/02-database-postgres) - Database credentials (10 min)
- [Rotation Dashboard](https://github.com/Keeper-Security/keeper-k8s-injector/tree/main/examples/06-rotation-dashboard) - Live rotation visualization (5 min)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                      Pod                             │
│  ┌──────────────┐         ┌──────────────────────┐  │
│  │    nginx     │         │   keeper-sidecar     │  │
│  │  (your app)  │         │   (injected)         │  │
│  │              │         │                      │  │
│  │  Reads from  │◄────────│  Writes secrets      │  │
│  │  /keeper/    │         │  from Keeper         │  │
│  │  secrets/    │         │  every 5m            │  │
│  └──────────────┘         └──────────────────────┘  │
│         ▲                          │                │
│         └──────────────────────────┘                │
│                  tmpfs volume                       │
│              (memory-backed tmpfs)                  │
└─────────────────────────────────────────────────────┘
```

## Comparison with External Secrets Operator

| Feature | Keeper Injector | ESO |
|---------|-----------------|-----|
| Creates K8s Secrets | No | Yes |
| Secret storage | Pod tmpfs (memory) | etcd |
| Secrets in etcd backups | No | Yes |
| Configuration | Annotations | CRDs |
| Runtime rotation | Yes (sidecar) | Sync interval |
| Pod isolation | Yes | Shared secrets |

**Use Keeper Injector when:** Security is paramount, you need secrets out of etcd, or require per-pod isolation.

**Use ESO when:** You need secrets as K8s Secret objects, or apps require environment variables only.

## Requirements

- Kubernetes 1.25+
- Keeper Secrets Manager application

## Links

- [GitHub Repository](https://github.com/Keeper-Security/keeper-k8s-injector)
- [Documentation](https://github.com/Keeper-Security/keeper-k8s-injector/tree/main/docs)
- [Docker Hub - Webhook](https://hub.docker.com/r/keeper/injector-webhook)
- [Docker Hub - Sidecar](https://hub.docker.com/r/keeper/injector-sidecar)
- [Keeper Secrets Manager](https://www.keepersecurity.com/secrets-manager.html)

## Support

- [GitHub Issues](https://github.com/Keeper-Security/keeper-k8s-injector/issues)
- [Keeper Support](https://www.keepersecurity.com/support.html)

## Maintainers

### Updating the Changelog for ArtifactHub

When releasing a new chart version, update the `artifacthub.io/changes` annotation in `Chart.yaml`:

1. Only include changes for the **current version**, not all previous versions
2. Use structured format with `kind` and `description`
3. Valid kinds: `added`, `changed`, `deprecated`, `removed`, `fixed`, `security`
4. Optionally add links to GitHub issues or PRs for traceability

Example:
```yaml
artifacthub.io/changes: |
  - kind: fixed
    description: Fixed connection refused error during initial installation
    links:
      - name: GitHub Issue
        url: https://github.com/Keeper-Security/keeper-k8s-injector/issues/1
  - kind: added
    description: Added automatic namespace labeling to prevent webhook self-injection
```

See `CHANGELOG-TEMPLATE.yaml` in this directory for a complete template.

**Important**: ArtifactHub generates the full changelog by combining the changes from all chart versions. Each version should only describe its own changes.

## License

MIT License - [Keeper Security, Inc.](https://www.keepersecurity.com)
