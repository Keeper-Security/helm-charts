# Keeper PAM Gateway

Deploy the [Keeper PAM Gateway](https://docs.keeper.io/en/keeperpam/privileged-access-manager/getting-started/gateways) on Kubernetes for remote access, secret rotation, and discovery.

## Quick Start

```bash
helm repo add keeper https://keeper-security.github.io/helm-charts
helm repo update
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<base64-config-from-keeper>'
```

The gateway connects outbound to Keeper infrastructure. No Ingress or inbound ports needed.

## Prerequisites

- Kubernetes 1.25+
- Keeper Enterprise account with the [Privileged Access Manager](https://docs.keeper.io/en/keeperpam/privileged-access-manager) add-on
- Gateway config from the [Keeper Vault](https://docs.keeper.io/en/keeperpam/privileged-access-manager/getting-started/gateways): **Secrets Manager** > select your Application > **Gateways** tab > **Provision Gateway** > choose **Docker** > copy the **Base64 Configuration**

## Installation

```bash
helm repo add keeper https://keeper-security.github.io/helm-charts
helm repo update
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<base64-config>'
```

### Using an Existing Secret

For production, store the gateway config in a Kubernetes Secret you manage separately (avoids exposing the config in shell history):

```bash
kubectl create namespace keeper-gateway
kubectl create secret generic gw-config \
  --from-literal=gateway-config='<base64-config>' -n keeper-gateway

helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway \
  --set gateway.acceptEula=Y \
  --set gateway.existingSecret=gw-config
```

## Verify

```bash
kubectl get pods -n keeper-gateway
kubectl logs -n keeper-gateway -l app.kubernetes.io/name=keeper-gateway
```

## Upgrade

```bash
helm upgrade keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway \
  --reuse-values
```

With the default strategy (`Recreate`), the existing pod is terminated before the new one starts. Active sessions will be disconnected. For zero-downtime upgrades, use `RollingUpdate` strategy with multiple replicas (see [Multi-Instance Scaling](#multi-instance-scaling)).

> **Note**: `--set gateway.config` passes the config through shell history and `helm get values`. For production, use `gateway.existingSecret` to keep the config in a Kubernetes Secret that you manage separately:
>
> ```bash
> helm upgrade keeper-gateway keeper/keeper-gateway \
>   --namespace keeper-gateway \
>   --set gateway.acceptEula=Y \
>   --set gateway.existingSecret=gw-config
> ```

## Common Configurations

### Multi-Instance Scaling

Run multiple gateway instances for high availability and load distribution. See the [Scaling and High Availability](https://docs.keeper.io/en/keeperpam/privileged-access-manager/getting-started/gateways/scaling-and-high-availability) guide for setup instructions.

```bash
# Fixed number of replicas (no autoscaling)
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set replicaCount=3 \
  --set strategy.type=RollingUpdate

# Or with autoscaling (HPA manages replica count automatically)
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set strategy.type=RollingUpdate \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=5
```

### KeeperAI Threat Detection

Use an LLM to monitor privileged sessions and flag suspicious commands in real time. See the [KeeperAI](https://docs.keeper.io/en/keeperpam/privileged-access-manager/keeperai) documentation for details and supported providers.

```bash
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set ai.enabled=true \
  --set ai.provider=openai \
  --set ai.model=gpt-4o-mini \
  --set ai.apiKey='<your-api-key>'
```

Supported providers include OpenAI, Anthropic, Azure OpenAI, Google AI, Vertex AI, AWS Bedrock, and any OpenAI-compatible endpoint (Ollama, vLLM, LM Studio, etc. via `openai-generic`).

For cloud-native authentication (AWS Bedrock with IRSA, Vertex AI with Workload Identity), use `serviceAccount.annotations` and `ai.existingSecret` or `extraEnv` instead of `ai.apiKey`.

### Logging

The gateway supports multiple log levels and output formats. Structured logging formats are available in gateway 1.8.0+.

```bash
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set logging.level=debug \
  --set logging.format=json
```

Supported levels: `error`, `warning`, `info`, `debug`, `trace`

Supported formats: `text`, `json`, `logfmt`, `cef`, `leef`, `rfc5424`, `rfc3164`, `gelf`

See the [Logging reference](#logging) below for all options including syslog forwarding.

> **Note**: Structured log formats (`json`, `logfmt`, `cef`, etc.) require gateway 1.8.0+. If using the default chart appVersion (1.7.6), override the image tag: `--set image.tag=1.8.0` or later.

### Demo / Playground Services

Deploy sample SSH, RDP, VNC, and MySQL containers alongside the gateway for testing and evaluation. These are disposable targets that the gateway can connect to, so you can try remote access, rotation, and discovery without setting up your own infrastructure.

Use the Keeper Vault "Provision Gateway" wizard with "Create with example records" checked, then plug in the generated config:

```bash
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config-from-wizard>' \
  --set demo.enabled=true
```

Individual services can be toggled on or off:

```bash
# Only SSH and MySQL
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set demo.enabled=true \
  --set demo.rdp.enabled=false \
  --set demo.vnc.enabled=false \
  --set demo.sshKey.enabled=false
```

Available demo services:

| Service | Image | Port | Default |
|---------|-------|------|---------|
| `demo.mysql` | mysql/mysql-server:8.0 | 3306 | Enabled |
| `demo.sshPassword` | keeper/playground-ssh | 2222 | Enabled |
| `demo.sshKey` | keeper/playground-ssh | 2222 | Enabled |
| `demo.vnc` | keeper/playground-vnc-xfce | 5901 | Enabled |
| `demo.rdp` | keeper/playground-rdp-xfce | 3389 | Enabled |

All demo passwords are configurable — override them with values from your Keeper Vault wizard output. See the [Demo Services reference](#demo-services) below.

### Corporate Proxy / Custom CA Certificates

If your network uses SSL inspection (e.g., Zscaler or other corporate proxies), the gateway needs your organization's CA certificate to establish outbound connections.

```bash
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set-file caCertificates.inline=./company-ca.pem
```

Or from a ConfigMap:

```bash
kubectl create configmap company-ca \
  --from-file=ca-certificates.crt=./company-ca.pem -n keeper-gateway

helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set caCertificates.existingConfigMap=company-ca
```

### Session Recordings Storage

By default, the gateway stores session recordings inside the container's filesystem. If the pod restarts, recordings are lost. Enable persistent storage to keep recordings across pod restarts:

```bash
helm install keeper-gateway keeper/keeper-gateway \
  --namespace keeper-gateway --create-namespace \
  --set gateway.acceptEula=Y \
  --set gateway.config='<config>' \
  --set recordings.enabled=true \
  --set recordings.size=50Gi
```

## Security Context

The gateway container starts as root to install CA certificates and Python packages at startup. It drops privileges to the `keeper-gw` user before starting services.

Do not set `runAsNonRoot: true` or `runAsUser` in the pod or container security context. If your cluster enforces Pod Security Standards, you may need an exemption for the gateway namespace.

## Configuration Reference

### Gateway Configuration

These are the core settings to connect the gateway to Keeper.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gateway.acceptEula` | Accept EULA (required, must be `"Y"`) | `""` |
| `gateway.config` | Base64-encoded gateway config from Keeper | `""` |
| `gateway.existingSecret` | Use a pre-created K8s secret instead of `gateway.config` | `""` |
| `gateway.existingSecretKey` | Key within the existing secret | `"gateway-config"` |
| `gateway.awsKmsSecretName` | Load config from AWS Secrets Manager instead | `""` |

### Image

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Gateway image repository | `keeper/gateway` |
| `image.tag` | Image tag (defaults to chart appVersion) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets for private registries | `[]` |

### Logging

Control the verbosity and format of gateway logs.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `logging.level` | Log level: `error`, `warning`, `info`, `debug`, `trace` | `"info"` |
| `logging.format` | Log format: `text`, `json`, `logfmt`, `cef`, `leef`, `rfc5424`, `rfc3164`, `gelf`. Structured formats available in gateway 1.8.0+. | `"text"` |
| `syslog.enabled` | Forward logs to a syslog server | `false` |
| `syslog.host` | Syslog server hostname or IP | `""` |
| `syslog.port` | Syslog server port | `514` |
| `syslog.proto` | Syslog transport: `tcp` or `udp` | `"udp"` |

### Health Check & Probes

The health check exposes an HTTP endpoint that Kubernetes uses to determine if the gateway is running and ready to accept connections.

Example enabling with a custom auth token:

```yaml
healthCheck:
  enabled: true
  port: 8099
  authToken: "my-monitoring-token"
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `healthCheck.enabled` | Enable the `/health` HTTP endpoint | `true` |
| `healthCheck.port` | Port for the health check server | `8099` |
| `healthCheck.authToken` | Optional Bearer token to secure the `/health` endpoint. External monitoring tools can use this token. Kubernetes probes always use TCP socket checks since the gateway rejects unauthenticated non-localhost requests. | `""` |
| `healthCheck.existingAuthTokenSecret` | Use a pre-created secret for the auth token | `""` |
| `healthCheck.existingAuthTokenSecretKey` | Key within the existing auth token secret | `"health-check-token"` |
| `probes.startup.enabled` | Enable startup probe (gives the gateway time to initialize and connect to Keeper) | `true` |
| `probes.startup.initialDelaySeconds` | Seconds to wait before first check | `10` |
| `probes.startup.periodSeconds` | How often to check | `10` |
| `probes.startup.failureThreshold` | How many failures before restarting (10 x 10s = 100s max startup) | `10` |
| `probes.liveness.enabled` | Enable liveness probe (restarts the pod if the gateway becomes unresponsive) | `true` |
| `probes.liveness.initialDelaySeconds` | Seconds to wait before first check | `30` |
| `probes.liveness.periodSeconds` | How often to check | `30` |
| `probes.liveness.timeoutSeconds` | Seconds before a check times out | `5` |
| `probes.liveness.failureThreshold` | Failures before restart | `3` |
| `probes.readiness.enabled` | Enable readiness probe (prevents traffic to a pod that isn't ready) | `true` |
| `probes.readiness.initialDelaySeconds` | Seconds to wait before first check | `15` |
| `probes.readiness.periodSeconds` | How often to check | `10` |
| `probes.readiness.timeoutSeconds` | Seconds before a check times out | `5` |
| `probes.readiness.failureThreshold` | Failures before marking unready | `3` |

### KeeperAI Threat Detection

Configure the AI provider used for [session threat analysis](https://docs.keeper.io/en/keeperpam/privileged-access-manager/keeperai). The API key is stored as a Kubernetes Secret.

Example:

```yaml
ai:
  enabled: true
  provider: "anthropic"
  model: "claude-sonnet-4-20250514"
  apiKey: "sk-ant-..."
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ai.enabled` | Enable KeeperAI session threat detection | `false` |
| `ai.provider` | LLM provider: `openai`, `openai-generic`, `azure-openai`, `anthropic`, `google-ai`, `vertex-ai`, `aws-bedrock` | `""` |
| `ai.model` | Model name (e.g., `gpt-4o-mini`, `claude-sonnet-4-20250514`, `gemini-pro`) | `""` |
| `ai.apiKey` | API key (stored in a K8s Secret, not in the ConfigMap) | `""` |
| `ai.existingSecret` | Use a pre-created secret for the API key | `""` |
| `ai.existingSecretKey` | Key within the existing secret | `"ai-api-key"` |
| `ai.baseUrl` | Custom API endpoint URL (for `openai-generic`, self-hosted LLMs, or proxied setups) | `""` |
| `ai.apiVersion` | API version (Azure OpenAI only) | `""` |
| `ai.projectId` | GCP Project ID (Vertex AI only) | `""` |
| `ai.location` | GCP region (Vertex AI only) | `""` |
| `ai.credentials` | Service account credentials as file path, JSON, or base64 (Vertex AI only) | `""` |

### Resource Management

The gateway tracks available memory and can reject new sessions when resources are low. This prevents the pod from running out of memory during heavy usage (e.g., multiple RBI/Chromium sessions consuming 800MB+ each).

- **enabled**: When `true`, the gateway checks available memory before accepting new connections. When `false`, all connections are accepted regardless of memory pressure.
- **minHeadroomPercent**: The minimum percentage of free memory the gateway keeps as a safety buffer. If free memory drops below this threshold, new sessions are rejected with a "resource unavailable" response. Higher values are more conservative (fewer concurrent sessions but safer). Lower values allow more sessions but risk OOM.
- **checkRbiCapacity**: When `true`, the gateway estimates whether a new Remote Browser Isolation (Chromium) session will fit in available RAM before starting it. RBI sessions are the most memory-intensive (~800MB each).

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resourceCheck.enabled` | Check available memory before accepting connections | `true` |
| `resourceCheck.minHeadroomPercent` | Minimum free memory percentage to maintain (higher = more conservative) | `15` |
| `resourceCheck.checkRbiCapacity` | Pre-check if an RBI session will fit in RAM before starting it | `true` |
| `resources.requests.cpu` | CPU request | `250m` |
| `resources.requests.memory` | Memory request | `512Mi` |
| `resources.limits.cpu` | CPU limit | `2` |
| `resources.limits.memory` | Memory limit. Increase this if running many concurrent sessions, especially RBI. | `2Gi` |

Per-protocol RAM estimates (e.g., RDP=75MB, SSH=70MB, RBI=800MB) can be tuned via `extraEnv` if needed. See the gateway documentation for details.

### TLS / CA Certificates

For networks with SSL inspection or self-signed certificates. The gateway installs these into the container's trust store at startup.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `caCertificates.inline` | PEM-formatted CA certificates (can contain multiple certs) | `""` |
| `caCertificates.existingConfigMap` | Load CA certs from a ConfigMap instead | `""` |
| `caCertificates.existingConfigMapKey` | Key within the ConfigMap | `"ca-certificates.crt"` |

### Storage

Persistent storage for session recordings. Without this, recordings are stored inside the container and lost on pod restart.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `recordings.enabled` | Create a persistent volume for session recordings | `false` |
| `recordings.storageClass` | Kubernetes storage class (empty = cluster default) | `""` |
| `recordings.accessModes` | Volume access modes (`ReadWriteOnce` or `ReadWriteMany` for multi-instance) | `[ReadWriteOnce]` |
| `recordings.size` | Volume size | `10Gi` |
| `recordings.existingClaim` | Use an existing PersistentVolumeClaim instead | `""` |
| `recordings.mountPath` | Path inside the container | `/opt/keeper/gateway/recordings` |
| `recordings.annotations` | Additional PVC annotations (e.g., for storage class options) | `{}` |
| `sharedMemory.enabled` | Mount /dev/shm with memory-backed storage (required for RBI/Chromium sessions) | `true` |
| `sharedMemory.sizeLimit` | Size limit for /dev/shm | `256Mi` |

### Network

The gateway connects outbound to Keeper infrastructure via WebSocket. The service exposed here is primarily for health check monitoring.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes Service type | `ClusterIP` |
| `service.port` | Service port (health check) | `8099` |
| `service.annotations` | Additional annotations on the Service | `{}` |
| `sessionAffinity` | Set to `"ClientIP"` for scaled deployments to keep sessions on the same pod | `""` |

### Scaling & Availability

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of gateway pods | `1` |
| `strategy.type` | Update strategy: `Recreate` (single instance) or `RollingUpdate` (multi-instance) | `Recreate` |
| `autoscaling.enabled` | Enable Horizontal Pod Autoscaler | `false` |
| `autoscaling.minReplicas` | Minimum pods | `1` |
| `autoscaling.maxReplicas` | Maximum pods | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | Scale up when average CPU exceeds this | `70` |
| `autoscaling.targetMemoryUtilizationPercentage` | Scale up when average memory exceeds this | `80` |
| `podDisruptionBudget.enabled` | Prevent cluster operations from taking down all pods at once | `false` |
| `podDisruptionBudget.minAvailable` | Minimum pods that must stay running during disruptions | `1` |
| `terminationGracePeriodSeconds` | Seconds to wait for active sessions to finish before killing the pod | `60` |

### Pod Placement

Control which cluster nodes the gateway pods run on.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Run pods only on nodes with these labels | `{}` |
| `tolerations` | Allow pods to run on tainted nodes | `[]` |
| `affinity` | Advanced rules for pod placement (e.g., spread across zones) | `{}` |
| `priorityClassName` | Kubernetes priority class for scheduling precedence | `""` |
| `topologySpreadConstraints` | Spread pods across failure domains | `[]` |

### Service Account

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a dedicated service account | `true` |
| `serviceAccount.annotations` | Annotations (e.g., `eks.amazonaws.com/role-arn` for AWS IRSA) | `{}` |
| `serviceAccount.name` | Custom name (auto-generated if empty) | `""` |

### Extensibility

Escape hatches for advanced configurations not covered by the chart's built-in values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `extraEnv` | Additional environment variables for the gateway container | `[]` |
| `extraEnvFrom` | Load env vars from ConfigMaps or Secrets | `[]` |
| `extraVolumes` | Additional volumes to attach to the pod | `[]` |
| `extraVolumeMounts` | Additional volume mounts for the gateway container | `[]` |
| `extraContainers` | Additional sidecar containers (e.g., log collectors) | `[]` |
| `initContainers` | Containers that run before the gateway starts | `[]` |
| `lifecycle` | Container lifecycle hooks (e.g., preStop for drain logic) | `{}` |
| `pipPackages` | Python packages to install at startup (space-separated) | `""` |
| `podAnnotations` | Additional pod annotations | `{}` |
| `podLabels` | Additional pod labels | `{}` |
| `podSecurityContext` | Pod-level security context (see [Security Context](#security-context)) | `{}` |
| `securityContext` | Container-level security context | `{}` |

Example — add a custom environment variable and a log collector sidecar:

```yaml
extraEnv:
  - name: KEEPER_GATEWAY_HTTP_RAM_MB
    value: "1200"

extraContainers:
  - name: log-forwarder
    image: fluent/fluent-bit:latest
    volumeMounts:
      - name: logs
        mountPath: /var/log

extraVolumes:
  - name: logs
    emptyDir: {}
```

### Demo Services

Sample containers for testing and evaluation. These deploy alongside the gateway and provide targets for remote access (SSH, RDP, VNC) and database connections (MySQL). Use the Keeper Vault "Provision Gateway" wizard with "Create with example records" to generate matching PAM records, then plug in the generated config.

All passwords are demo placeholders. Replace them with values from your Keeper Vault wizard output.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `demo.enabled` | Deploy playground services | `false` |
| `demo.mysql.enabled` | MySQL server (port 3306) | `true` |
| `demo.mysql.rootPassword` | MySQL root password (demo placeholder) | `"DEMO-ONLY-..."` |
| `demo.mysql.user` | MySQL application user | `"sqluser"` |
| `demo.mysql.password` | MySQL application password (demo placeholder) | `"DEMO-ONLY-..."` |
| `demo.sshPassword.enabled` | SSH server with password auth (port 2222) | `true` |
| `demo.sshPassword.user` | SSH user | `"linuxuser"` |
| `demo.sshPassword.password` | SSH password (demo placeholder) | `"DEMO-ONLY-..."` |
| `demo.sshKey.enabled` | SSH server with key auth (port 2222) | `true` |
| `demo.sshKey.user` | SSH user | `"linuxuser"` |
| `demo.vnc.enabled` | VNC server (port 5901) | `true` |
| `demo.vnc.password` | VNC password (demo placeholder) | `"DEMO-vnc"` |
| `demo.rdp.enabled` | RDP server (port 3389) | `true` |
| `demo.rdp.user` | RDP user | `"rdpuser"` |
| `demo.rdp.password` | RDP password (demo placeholder) | `"DEMO-ONLY-..."` |

## Uninstall

```bash
helm uninstall keeper-gateway -n keeper-gateway
kubectl delete namespace keeper-gateway
```

If session recordings storage was enabled, the persistent volume is not deleted automatically (Kubernetes retains persistent volumes to prevent accidental data loss). To delete it:

> **Warning**: This permanently destroys all stored session recordings. Verify you have backed up any needed recordings before proceeding.

```bash
kubectl delete pvc -n keeper-gateway -l app.kubernetes.io/name=keeper-gateway
```

## Links

- [Gateway Documentation](https://docs.keeper.io/en/keeperpam/privileged-access-manager/getting-started/gateways)
- [Scaling & High Availability](https://docs.keeper.io/en/keeperpam/privileged-access-manager/getting-started/gateways/scaling-and-high-availability)
- [KeeperAI](https://docs.keeper.io/en/keeperpam/privileged-access-manager/keeperai)
- [Docker Hub](https://hub.docker.com/r/keeper/gateway)
- [Helm Charts Repository](https://github.com/Keeper-Security/helm-charts)
- [Keeper Security](https://www.keepersecurity.com)
- [Support](https://www.keepersecurity.com/support.html)

## License

MIT License - [Keeper Security, Inc.](https://www.keepersecurity.com)
