# Coolify Helm Chart

This Helm chart deploys [Coolify](https://coolify.io/), a self-hostable open-source PaaS (Platform as a Service) for managing applications, databases, and services with a modern UI.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure
- LoadBalancer support (optional, for external access)

## Installing the Chart

To install the chart with the release name `coolify`:

```bash
# Add the repository (replace with your actual repository)
helm repo add coolify-repo https://your-repo-url/charts

# Update the repository
helm repo update

# Install the chart
helm install coolify coolify-repo/coolify --namespace coolify --create-namespace
```

Or to install from local chart directory:

```bash
# Navigate to the chart directory
cd charts/coolify

# Install with authentication fixes applied
helm install coolify . --namespace coolify --create-namespace
```

> **🔐 Authentication Fix**: This chart includes fixes for Redis "WRONGPASS" and PostgreSQL authentication issues. All passwords are automatically synchronized between Coolify and its dependencies.

> **🗄️ Database Migration Fix**: This chart includes automatic database migration support. The initContainer runs `php artisan migrate` before the main application starts, ensuring the required database schema (including `instance_settings` table) is created.

## Uninstalling the Chart

To uninstall/delete the `coolify` deployment:

```bash
helm uninstall coolify
```

## Configuration

The following table lists the configurable parameters of the Coolify chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|------|
| `global.namespace` | Namespace to install Coolify | `coolify` |
| `global.registryUrl` | Docker registry URL | `ghcr.io` |
| `global.storageClassName` | Default storage class |
| `coolifyApp.enabled` | Enable Coolify application | `true` |
| `coolifyApp.replicaCount` | Number of Coolify replicas | `1` |
| `coolifyApp.migration.enabled` | Enable automatic database migration | `true` |
| `coolifyApp.migration.timeout` | Migration timeout in seconds | `300` |
| `coolifyApp.migration.runSeeders` | Run database seeders after migration | `false` |
| `coolifyApp.image.repository` | Coolify image repository | `coollabsio/coolify` |
| `coolifyApp.image.tag` | Coolify image tag | `""` (defaults to Chart.appVersion) |
| `coolifyApp.service.type` | Coolify service type | `ClusterIP` |
| `coolifyApp.podDisruptionBudget.enabled` | Enable Pod Disruption Budget | `true` |
| `coolifyApp.podDisruptionBudget.minAvailable` | Minimum available pods | `1` |
| `coolifyApp.autoscaling.enabled` | Enable Horizontal Pod Autoscaler | `false` |
| `coolifyApp.autoscaling.minReplicas` | Minimum replicas | `1` |
| `coolifyApp.autoscaling.maxReplicas` | Maximum replicas | `10` |
| `coolifyApp.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization | `80` |
| `coolifyApp.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization | `80` |
| `soketi.podDisruptionBudget.enabled` | Enable Soketi Pod Disruption Budget | `true` |
| `soketi.podDisruptionBudget.minAvailable` | Minimum available Soketi pods | `1` |
| `soketi.autoscaling.enabled` | Enable Soketi Horizontal Pod Autoscaler | `false` |
| `soketi.autoscaling.minReplicas` | Minimum Soketi replicas | `1` |
| `soketi.autoscaling.maxReplicas` | Maximum Soketi replicas | `5` |
| `soketi.autoscaling.targetCPUUtilizationPercentage` | Target Soketi CPU utilization | `80` |
| `config.APP_URL` | Coolify application URL | `http://localhost:8000` |
| `secrets.ROOT_USERNAME` | Coolify root username | `""` (auto-generated) |
| `secrets.ROOT_USER_PASSWORD` | Coolify root password | `""` (auto-generated) |
| `postgresql.enabled` | Deploy PostgreSQL | `true` |
| `redis.enabled` | Deploy Redis | `true` |
| `soketi.enabled` | Deploy Soketi (Realtime server) | `true` |
| `sharedDataPvc.size` | Shared PVC size | `10Gi` |

Refer to [values.yaml](./charts/coolify/values.yaml) for the full list of parameters.

## Production Readiness Features

### High Availability & Scaling

- **Pod Disruption Budgets (PDB)**: Automatically configured for both Coolify app and Soketi to ensure minimum availability during cluster maintenance
- **Horizontal Pod Autoscaler (HPA)**: Optional autoscaling based on CPU and memory utilization
- **Resource Management**: Pre-configured resource requests and limits for optimal resource allocation

### Example: Enable Autoscaling

```yaml
# values.yaml
coolifyApp:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

soketi:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
```

### Example: Customize Pod Disruption Budget

```yaml
# values.yaml
coolifyApp:
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
    # Or use maxUnavailable instead:
    # maxUnavailable: 1

soketi:
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

## Architecture

The Coolify Helm chart deploys the following components:

1. **Coolify App**: The main application
2. **PostgreSQL**: For data storage
3. **Redis**: For caching and queuing
4. **Soketi**: For realtime features

## Persistence

The chart mounts persistent volumes for:

- Coolify shared data
- PostgreSQL database
- Redis data

## Security Considerations

- Auto-generated passwords are used if not specified
- Consider using an external secrets manager for production deployments
- Global security context settings can be configured in values.yaml
- See [SECURITY-CONTEXT.md](./SECURITY-CONTEXT.md) for detailed security configuration

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.