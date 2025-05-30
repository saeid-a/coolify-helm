# Coolify Helm Chart Deployment Guide

## Quick Start

### 1. Install Dependencies
```bash
helm dependency update
```

### 2. Deploy with Custom Passwords (Recommended)
```bash
helm install coolify . \
  --set postgresql.auth.password="your-db-password-here" \
  --set redis.auth.password="your-redis-password-here" \
  --set secrets.DB_PASSWORD="your-db-password-here" \
  --set secrets.REDIS_PASSWORD="your-redis-password-here" \
  --set config.APP_URL="http://your-domain.com" \
  --namespace coolify \
  --create-namespace
```

### 3. Or Deploy with Default Passwords (Development Only)
```bash
helm install coolify . \
  --set config.APP_URL="http://localhost:8000" \
  --namespace coolify \
  --create-namespace
```

## Authentication Issues Fix

If you encounter Redis authentication error:
```
WRONGPASS invalid username-password pair or user is disabled.
```

Or PostgreSQL authentication error:
```
SQLSTATE[08006] [7] connection to server failed: FATAL: password authentication failed for user "coolify"
```

These have been fixed in the current chart by ensuring all subcharts and Coolify use synchronized passwords through:

1. **PostgreSQL**: `postgresql.auth.password` = `secrets.DB_PASSWORD`
2. **Redis**: `redis.auth.password` = `secrets.REDIS_PASSWORD`

The synchronization happens automatically via the `00-redis-password-sync.yaml` template.

## Database Migration Fix

If you encounter database schema errors:
```
SQLSTATE[42P01]: Undefined table: 7 ERROR: relation "instance_settings" does not exist
```

This has been fixed in the current chart by adding automatic database migration support:

### Migration Features ✅

- **InitContainer**: Automatically runs `php artisan migrate --force` before the main application starts
- **Database Readiness**: Waits for PostgreSQL to be ready before running migrations
- **Error Handling**: Provides clear logs and error messages for troubleshooting
- **Configurable**: Migration can be disabled or customized via values.yaml

### Migration Configuration

You can configure the database migration behavior in `values.yaml`:

```yaml
coolifyApp:
  migration:
    enabled: true           # Enable/disable migrations
    timeout: 300           # Timeout for migration in seconds
    runSeeders: false      # Run database seeders after migrations
```

To disable migrations (if you want to run them manually):

```yaml
coolifyApp:
  migration:
    enabled: false
```

### Migration Process

The migration initContainer will:
1. Wait for PostgreSQL database to be ready
2. Run Laravel database migrations (`php artisan migrate --force`)
3. Optionally run database seeders (if enabled)
4. Ensure the `instance_settings` table and other required schema exist
5. Allow the main application container to start

### Manual Migration

If you prefer to run migrations manually:

```bash
# Disable automatic migration in values.yaml
# coolifyApp.migration.enabled: false

# Run migration manually after deployment
kubectl exec -it deployment/coolify-app -n coolify -- php artisan migrate
```

## Storage Permission Fix

If you encounter storage directory creation errors:
```
Unable to create a directory at /var/www/html/storage/app/ssh/keys
Could not setup dynamic configuration: Call to a member function setupDynamicProxyConfiguration() on null
```

This has been fixed in the current chart by adding proper storage setup:

### Storage Features ✅

- **Storage InitContainer**: Automatically creates all required directories before the main app starts
- **Proper Permissions**: Sets correct ownership and permissions (775) for Laravel storage directories
- **Directory Structure**: Creates complete directory tree including SSH keys, logs, cache, etc.
- **Volume Mounts**: Properly mounts persistent storage for all application data

### Storage Configuration

The storage setup initContainer will:
1. Create all required storage directories:
   - `/var/www/html/storage/app/ssh/keys` - SSH key storage
   - `/var/www/html/storage/app/applications` - Application data
   - `/var/www/html/storage/app/databases` - Database backups
   - `/var/www/html/storage/app/services` - Service configurations
   - `/var/www/html/storage/logs` - Application logs
   - `/var/www/html/bootstrap/cache` - Laravel bootstrap cache
2. Set proper permissions (775) for all directories
3. Ensure www-data user ownership
4. Allow the main application to start with proper storage access

### Manual Storage Setup

If you need to fix storage issues manually:

```bash
# Check storage permissions
kubectl exec -it deployment/coolify-app -n coolify -- ls -la /var/www/html/storage/

# Fix permissions if needed
kubectl exec -it deployment/coolify-app -n coolify -- chmod -R 775 /var/www/html/storage
kubectl exec -it deployment/coolify-app -n coolify -- chown -R www-data:www-data /var/www/html/storage
```

## Production Deployment

For production, always set custom passwords:

```bash
# Create a values-production.yaml file
cat > values-production.yaml << EOF
config:
  APP_URL: "https://coolify.yourdomain.com"
  APP_ENV: "production"

postgresql:
  auth:
    password: "$(openssl rand -base64 32)"

redis:
  auth:
    password: "$(openssl rand -base64 32)"

secrets:
  DB_PASSWORD: "$(openssl rand -base64 32)"
  REDIS_PASSWORD: "$(openssl rand -base64 32)"
  
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: coolify.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: coolify-tls
      hosts:
        - coolify.yourdomain.com
EOF

# Deploy
helm install coolify . -f values-production.yaml --namespace coolify --create-namespace
```

## Troubleshooting

### Authentication Issues (RESOLVED ✅)

**Previous Issues (Now Fixed):**
- Redis: `WRONGPASS invalid username-password pair or user is disabled`
- PostgreSQL: `SQLSTATE[08006] [7] password authentication failed for user 'coolify'`

**Solution Implemented:**
✅ **Password Synchronization**: All passwords are now synchronized between Coolify and subcharts  
✅ **Service Discovery**: FQDN-based service resolution within the same namespace  
✅ **Namespace Consistency**: All components deploy in the same Kubernetes namespace

**Current Authentication Configuration:**
- **Redis Password**: `<auto-generated-at-deployment>`
- **PostgreSQL User Password**: `<auto-generated-at-deployment>` 
- **PostgreSQL Admin Password**: `<auto-generated-at-deployment>`

**Key Fix Details:**
1. **Service Names**: Services resolve via FQDN (e.g., `test-postgresql.coolify.svc.cluster.local`)
2. **Password Sync**: Template `00-redis-password-sync.yaml` ensures subchart passwords match Coolify secrets
3. **ConfigMap**: Uses proper helper functions for service name resolution

### Database Migration Issues (RESOLVED ✅)

**Previous Issues (Now Fixed):**
- `SQLSTATE[42P01]: Undefined table: 7 ERROR: relation "instance_settings" does not exist`
- Database schema not being created during deployment

**Solution Implemented:**
✅ **Automatic Migration**: InitContainer runs `php artisan migrate` before main app starts  
✅ **Database Readiness**: Waits for PostgreSQL to be available before migration  
✅ **Error Handling**: Clear logging and error reporting for migration issues  
✅ **Configurable**: Migration behavior can be customized via values.yaml

**Migration Process:**
1. InitContainer waits for database connection
2. Runs Laravel migrations automatically
3. Creates all required database schema
4. Main application starts with proper database structure

### Check Migration Status

```bash
# Check initContainer logs for migration
kubectl logs <pod-name> -c migrate-database -n coolify

# Check if migration was successful
kubectl logs <pod-name> -c migrate-database -n coolify | grep "Database migration completed successfully"

# Verify database schema exists
kubectl exec -n coolify <postgres-pod> -- psql -U coolify -d coolify -c "\dt instance_settings"
```

### Storage Permission Issues (RESOLVED ✅)

**Previous Issues (Now Fixed):**
- `Unable to create a directory at /var/www/html/storage/app/ssh/keys`
- `Could not setup dynamic configuration: Call to a member function setupDynamicProxyConfiguration() on null`
- Storage permission denied errors

**Solution Implemented:**
✅ **Storage InitContainer**: Automatically creates all required directories with proper permissions  
✅ **Permission Management**: Sets correct ownership (www-data) and permissions (775)  
✅ **Volume Mounting**: Properly mounts persistent storage for application data  
✅ **Directory Structure**: Creates complete Laravel storage directory tree

**Storage Setup Process:**
1. InitContainer runs as root to create directories
2. Sets proper permissions and ownership
3. Main application starts with full storage access
4. All SSH keys, logs, and application data persist correctly

### Check Storage Status

```bash
# Check storage setup initContainer logs
kubectl logs <pod-name> -c setup-storage -n coolify

# Verify storage permissions
kubectl exec -n coolify <coolify-pod> -- ls -la /var/www/html/storage/

# Check if SSH keys directory is accessible
kubectl exec -n coolify <coolify-pod> -- test -w /var/www/html/storage/app/ssh/keys && echo "SSH keys directory is writable"
```

### Check Service Status
```bash
kubectl get pods -n coolify
kubectl get svc -n coolify
```

### Check Secrets
```bash
kubectl get secret coolify-app-secrets -n coolify -o yaml
```

### View Logs
```bash
kubectl logs -f deployment/coolify-app -n coolify
kubectl logs -f deployment/coolify-soketi -n coolify
```

### Password Verification
```bash
# Check Redis password
kubectl get secret coolify-app-secrets -n coolify -o jsonpath="{.data.REDIS_PASSWORD}" | base64 --decode

# Check DB password  
kubectl get secret coolify-app-secrets -n coolify -o jsonpath="{.data.DB_PASSWORD}" | base64 --decode
```
