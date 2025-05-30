# Security Context Configuration

This document describes the security context configuration for the Coolify Helm chart and how to customize it for your environment.

## Overview

The chart now supports comprehensive security context configuration at both the Pod and container levels through the global `securityContext` settings in `values.yaml`. These settings can be used to configure:

- User and group ID management
- Non-root user execution
- Privilege escalation controls
- Filesystem permissions
- Linux capabilities

## Default Security Context Settings

The default security context settings are defined in `values.yaml` (around lines 208-217):

```yaml
securityContext:
  enabled: true
  fsGroup: 1000
  runAsUser: 1000
  runAsGroup: 1000
  runAsNonRoot: true
  # Additional security options
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false # Coolify needs write access
  capabilities:
    drop:
      - ALL
```

## Container-Specific Security Contexts

Some containers in the deployment need to run as root during initialization or for specific tasks, such as:

1. **Setup containers** - Need root access to set up directory permissions
2. **Migration container** - Needs root access to run as the www-data user
3. **Main application container** - Needs root initially for nginx configuration

For these containers, the security context has been modified to:
- Always run as root (overriding global settings) where necessary
- Apply other security restrictions from the global settings where possible
- Document the security requirements and reasons

## Deployment Structure

The security context settings are applied at multiple levels:

1. **Pod-level security context** - Applied to all containers that don't override it
2. **Container-specific security contexts** - Applied to individual containers, with overrides when necessary

## Customizing Security Context

To customize the security context for your environment:

1. Edit the `securityContext` section in your custom values file
2. Enable or disable the global security context with `securityContext.enabled`
3. Set appropriate values for your environment

Example:

```yaml
securityContext:
  enabled: true
  fsGroup: 1000
  runAsUser: 1000
  runAsGroup: 1000
  runAsNonRoot: false  # Set to false if you need root access
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE  # If needed for binding to ports < 1024
```

## Security Best Practices

When deploying to production, consider these additional security measures:

1. Use a dedicated namespace with Network Policies
2. Apply Pod Security Standards (PSS) at the namespace level
3. Use ResourceQuotas and LimitRanges
4. Consider implementing additional monitoring for security events

## Known Limitations

### Main Container Root Requirements

The main Coolify application container **requires root access** for essential runtime operations:

1. **User Management**: Creating and managing the www-data user (addgroup, adduser)
2. **File Ownership**: Setting proper ownership of application files (chown)
3. **Service Configuration**: Configuring PHP-FPM and nginx at runtime
4. **Process Management**: Using 'su' commands to run Laravel commands as www-data user

**Important**: Even when `securityContext.enabled: false`, the main container will run as root (UID 0) to ensure compatibility. This is by design and necessary for proper application functionality.

### Security Best Practices

While the main container runs as root, security is maintained through:

1. **Init Container Isolation**: Heavy setup operations are isolated to init containers
2. **Process Separation**: Application processes (PHP-FPM) run as www-data user
3. **Capability Restrictions**: Only necessary Linux capabilities are granted
4. **Runtime Principle**: Root access is used only for setup, not for serving requests

Future versions will work towards reducing privileged operations where possible through pre-built image configurations.
