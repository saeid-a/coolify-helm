# Coolify Helm Chart (Community)

This is a **community-maintained** production-ready Helm chart for deploying [Coolify](https://coolify.io/), a self-hostable open-source PaaS (Platform as a Service) for managing applications, databases, and services with a modern UI.

> **⚠️ Important Notice**: This is an **unofficial community project** and is not maintained by or affiliated with the official Coolify team. For official Coolify support, please visit the [official Coolify documentation](https://coolify.io/docs) and [GitHub repository](https://github.com/coollabsio/coolify).

## Prerequisites

### Minimum Requirements
- **Kubernetes**: 1.24+ (recommended 1.28+)
- **Helm**: 3.8.0+
- **Storage**: Persistent Volume provisioner
- **Resources**: 2 CPU cores, 4GB RAM minimum per node

### Production Requirements
- **Load Balancer**: For external access (NGINX Ingress, AWS ALB, etc.)
- **DNS**: Wildcard DNS for application routing
- **Certificates**: TLS certificates for HTTPS (cert-manager recommended)
- **Monitoring**: Prometheus/Grafana for observability
- **Backup**: Volume snapshot capability for data protection

## Quick Start

### Adding the Helm Repository

This chart is published to GitHub Pages and can be added as a Helm repository:

```bash
# Add the community Coolify Helm repository
helm repo add coolify-community https://saeid-a.github.io/coolify-helm
helm repo update
```

> **📦 Chart Distribution**: The Helm charts are automatically packaged and published to GitHub Pages using GitHub Actions. Each release creates a new chart version available through the repository.

### Development Installation

For development and testing environments:

```bash
# Install with development defaults
helm install coolify coolify-community/coolify \
  --namespace coolify \
  --create-namespace \
  --set config.APP_URL=http://localhost:8000
```

### Production Installation

For production deployments with high availability:

```bash
# Create production values file
cat > production-values.yaml << EOF
# ===== Application Configuration =====
# Core Coolify settings - adjust APP_URL to match your domain
config:
  APP_URL: https://coolify.your-domain.com  # Must match your actual domain
  APP_ENV: production                       # Enables production optimizations
  APP_DEBUG: false                         # Disable debug mode for security

# ===== High Availability Configuration =====
# Main Coolify application scaling and reliability settings
coolifyApp:
  replicaCount: 3                         # Start with 3 replicas for HA
  autoscaling:
    enabled: true                         # Enable automatic scaling based on load
    minReplicas: 3                        # Never scale below 3 for HA
    maxReplicas: 10                       # Maximum replicas under high load
    targetCPUUtilizationPercentage: 70    # Scale up when CPU exceeds 70%
  podDisruptionBudget:
    enabled: true                         # Prevent all pods from being terminated during maintenance
    minAvailable: 2                       # Always keep at least 2 pods running
  resources:
    requests:                             # Guaranteed resources per pod
      memory: "1Gi"                       # Minimum memory allocation
      cpu: "500m"                         # Minimum CPU allocation (0.5 cores)
    limits:                               # Maximum resources per pod
      memory: "2Gi"                       # Maximum memory before OOM kill
      cpu: "1000m"                        # Maximum CPU usage (1 core)

# ===== Real-time Service Configuration =====
# Soketi handles WebSocket connections for real-time features
soketi:
  replicaCount: 2                         # Start with 2 replicas for redundancy
  autoscaling:
    enabled: true                         # Enable automatic scaling for WebSocket load
    minReplicas: 2                        # Minimum replicas for redundancy
    maxReplicas: 5                        # Maximum replicas for WebSocket connections

# ===== Storage Configuration =====
# Persistent storage for application data and logs
sharedDataPvc:
  size: 50Gi                              # Storage size for Coolify data (adjust based on usage)
  storageClassName: fast-ssd              # Use fast SSD storage class for better performance

# ===== Database Configuration =====
# PostgreSQL settings for production workloads
postgresql:
  primary:
    persistence:
      size: 20Gi                          # Database storage size (adjust based on data volume)
      storageClass: fast-ssd              # Use fast SSD for database performance
    resources:
      requests:                           # Guaranteed database resources
        memory: 1Gi                       # Minimum memory for PostgreSQL
        cpu: 500m                         # Minimum CPU for database operations
      limits:                             # Maximum database resources
        memory: 2Gi                       # Maximum memory before OOM kill
        cpu: 1000m                        # Maximum CPU for database operations

# ===== External Access Configuration =====
# Ingress controller setup for HTTPS access
ingress:
  enabled: true                           # Enable external access via ingress
  className: nginx                        # Use NGINX ingress controller
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod  # Automatic SSL certificate generation
    nginx.ingress.kubernetes.io/ssl-redirect: "true"  # Force HTTPS redirects
  hosts:
    - host: coolify.your-domain.com       # Your actual domain name
      paths:
        - path: /                         # Serve all paths
          pathType: Prefix
  tls:
    - secretName: coolify-tls             # TLS certificate secret name
      hosts:
        - coolify.your-domain.com         # Domain for SSL certificate

# ===== Security Configuration =====
# Pod security settings for production environments
securityContext:
  enabled: true                           # Enable security context restrictions
  allowPrivilegeEscalation: false        # Prevent privilege escalation attacks
  readOnlyRootFilesystem: false          # Allow writes to root filesystem (required for Coolify)

# ===== Monitoring Configuration =====
# Prometheus monitoring integration
serviceMonitor:
  enabled: true                           # Enable Prometheus metrics collection
  namespace: monitoring                   # Namespace where Prometheus is installed
EOF

# Deploy with production configuration
helm install coolify coolify-community/coolify \
  --namespace coolify \
  --create-namespace \
  --values production-values.yaml \
  --timeout 10m
```

### Local Development Installation

```bash
# Clone the repository
git clone <repository-url>
cd coolify-helm

# Install from local chart with authentication fixes
helm install coolify ./charts/coolify \
  --namespace coolify \
  --create-namespace \
  --set config.APP_URL=http://localhost:8000
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

## 🚀 Production Features

This Helm chart is designed with enterprise-grade capabilities to ensure reliable, secure, and scalable Coolify deployments in production Kubernetes environments.

✅ **High Availability & Scaling**
- Pod Disruption Budgets (PDB) for zero-downtime maintenance
- Horizontal Pod Autoscaler (HPA) with CPU/memory metrics
- Multi-replica support with proper load balancing

✅ **Security & Compliance**
- Automated secret generation with secure defaults
- Configurable security contexts and Pod Security Standards
- RBAC ready configuration
- Non-root container execution where possible

✅ **Operational Excellence**
- Comprehensive health checks and monitoring
- Automatic database migrations with rollback support
- Resource management with requests/limits
- Persistent storage with proper backup strategies

✅ **Enterprise Ready**
- Support for external databases (PostgreSQL, Redis)
- Ingress configuration with TLS termination
- Network policies for micro-segmentation
- Prometheus metrics and observability

## Contributing

This is a community-maintained project. Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

### Reporting Issues

- For issues with this Helm chart specifically, please open an issue in this repository
- For general Coolify questions or issues, please refer to the [official Coolify repository](https://github.com/coollabsio/coolify)
- Make sure to specify that you're using this community Helm chart when reporting issues