# Security Configuration Guide

## 🔐 Password Security

This Helm chart implements secure password generation by default. All passwords are automatically generated using cryptographically secure random functions if not explicitly provided.

### Auto-Generated Secrets

The following secrets are **automatically generated** at deploy time:

| Secret | Length | Description |
|--------|--------|-------------|
| `APP_ID` | 32 chars | Application identifier |
| `APP_KEY` | 32 chars + prefix | Laravel encryption key (base64: prefixed) |
| `DB_PASSWORD` | 32 chars | PostgreSQL user password |
| `REDIS_PASSWORD` | 32 chars | Redis authentication password |
| `PUSHER_APP_ID` | 32 chars | Pusher/Soketi app identifier |
| `PUSHER_APP_KEY` | 32 chars | Pusher/Soketi app key |
| `PUSHER_APP_SECRET` | 32 chars | Pusher/Soketi app secret |
| `ROOT_USER_PASSWORD` | 20 chars | Admin user password (if configured) |

### 🚀 Deployment Examples

#### 1. **Secure Default Deployment**
```bash
# All passwords auto-generated securely
helm install coolify ./charts/coolify -n coolify
```

#### 2. **Custom Password Override**
```bash
# Override specific passwords
helm install coolify ./charts/coolify -n coolify \
  --set postgresql.auth.password=your-secure-db-password \
  --set redis.auth.password=your-secure-redis-password \
  --set secrets.APP_KEY=base64:your-custom-app-key
```

#### 3. **Values File Override**
```yaml
# values-production.yaml
postgresql:
  auth:
    password: "your-secure-database-password"
    postgresPassword: "your-secure-admin-password"

redis:
  auth:
    password: "your-secure-redis-password"

secrets:
  APP_KEY: "base64:your-custom-laravel-key"
  ROOT_USERNAME: "admin"
  ROOT_USER_EMAIL: "admin@example.com"
  ROOT_USER_PASSWORD: "your-secure-admin-password"
```

```bash
helm install coolify ./charts/coolify -n coolify -f values-production.yaml
```

### 🔍 Retrieving Generated Passwords

After deployment, you can retrieve the auto-generated passwords:

```bash
# Get all secrets
kubectl get secret coolify-app-secrets -n coolify -o yaml

# Get specific password (base64 decoded)
kubectl get secret coolify-app-secrets -n coolify -o jsonpath="{.data.DB_PASSWORD}" | base64 --decode

kubectl get secret coolify-app-secrets -n coolify -o jsonpath="{.data.REDIS_PASSWORD}" | base64 --decode

kubectl get secret coolify-app-secrets -n coolify -o jsonpath="{.data.APP_KEY}" | base64 --decode
```

### 🔄 Password Rotation

To rotate passwords:

1. **Generate new passwords** and update your values:
```bash
helm upgrade coolify ./charts/coolify -n coolify \
  --set postgresql.auth.password=new-secure-password \
  --set redis.auth.password=new-secure-password
```

2. **Or delete secrets** to trigger regeneration:
```bash
kubectl delete secret coolify-app-secrets -n coolify
helm upgrade coolify ./charts/coolify -n coolify
```

### ⚠️ Security Best Practices

1. **Never commit passwords** to version control
2. **Use external secret management** for production (e.g., HashiCorp Vault, AWS Secrets Manager)
3. **Regularly rotate passwords**
4. **Monitor secret access** with RBAC and audit logs
5. **Use TLS encryption** for all database connections
6. **Backup secrets securely** before cluster operations

### 🛡️ External Secret Management

For production environments, consider integrating with external secret management:

#### Using External Secrets Operator
```yaml
# Example: external-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "coolify"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: coolify-secrets
spec:
  refreshInterval: 60s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: coolify-app-secrets
  data:
  - secretKey: DB_PASSWORD
    remoteRef:
      key: coolify
      property: db_password
```

#### Using Sealed Secrets
```bash
# Create sealed secret
echo -n 'your-secure-password' | kubectl create secret generic coolify-db-password \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > coolify-db-sealed-secret.yaml
```

### 📋 Security Checklist

- [ ] All default passwords removed from values.yaml
- [ ] Auto-generation enabled for all secrets
- [ ] Production passwords stored in external secret management
- [ ] TLS enabled for database connections
- [ ] RBAC configured for secret access
- [ ] Regular password rotation scheduled
- [ ] Backup and recovery procedures tested
- [ ] Security scanning enabled for container images
- [ ] Network policies configured (if needed)
- [ ] Monitoring and alerting configured for security events
