{{/*
Main Coolify application container
*/}}
{{- define "coolify.container.main" -}}
- name: coolify
  image: "{{ .Values.coolifyApp.image.repository }}:{{ .Values.coolifyApp.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.coolifyApp.image.pullPolicy | default "IfNotPresent" }}
  command: ["/bin/sh"]
  args:
    - -c
    - |
      {{- include "coolify.container.startupScript" . | nindent 6 }}
  ports:
    - name: http
      containerPort: {{ .Values.coolifyApp.service.targetPort }}
      protocol: TCP
  envFrom:
    - configMapRef:
        name: {{ include "coolify.configMap.name" . }}
    - secretRef:
        name: {{ include "coolify.secret.name" . }}
  volumeMounts:
    - name: shared-data
      mountPath: /var/www/html/storage/app
      subPath: coolify/storage
    - name: shared-data
      mountPath: /var/www/html/storage/logs
      subPath: coolify/logs
    - name: shared-data
      mountPath: /var/www/html/bootstrap/cache
      subPath: coolify/bootstrap-cache
  workingDir: {{ .Values.coolifyApp.workingDir | default "/var/www/html" }}
  {{- include "coolify.container.securityContext" . | nindent 2 }}
  {{- include "coolify.container.healthChecks" . | nindent 2 }}
  {{- include "coolify.container.resources" . | nindent 2 }}
{{- end -}}

{{/*
Main container startup script
*/}}
{{- define "coolify.container.startupScript" -}}
echo "Starting Coolify with PHP-FPM configuration..."

# Ensure www-data user exists
id www-data >/dev/null 2>&1 || {
  echo "Creating www-data user..."
  addgroup -g 82 -S www-data 2>/dev/null || true
  adduser -u 82 -D -S -s /sbin/nologin -G www-data www-data 2>/dev/null || true
}

echo "www-data user info:"
id www-data 2>/dev/null || echo "www-data user not found"

# Configure PHP-FPM
{{- include "coolify.container.phpFpmConfig" . | nindent 0 }}

# Configure PHP-FPM before starting any services
configure_phpfpm

# Laravel application optimization for production
echo "Optimizing Laravel application for production..."
cd /var/www/html

# Ensure proper ownership and permissions
# Only change ownership if needed
if [ "$(stat -c %U:%G /var/www/html/storage)" != "www-data:www-data" ]; then
  echo "Fixing storage ownership..."
  chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
fi
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Run Laravel optimizations as www-data (only if not already cached)
if [ ! -f "/var/www/html/bootstrap/cache/config.php" ]; then
  su -s /bin/sh www-data -c "php artisan config:cache" || echo "Config cache failed, continuing..."
fi

if [ ! -f "/var/www/html/bootstrap/cache/routes-v7.php" ]; then
  su -s /bin/sh www-data -c "php artisan route:cache" || echo "Route cache failed, continuing..."
fi

if [ ! -f "/var/www/html/storage/framework/views" ] || [ -z "$(ls -A /var/www/html/storage/framework/views 2>/dev/null)" ]; then
  su -s /bin/sh www-data -c "php artisan view:cache" || echo "View cache failed, continuing..."
fi

# Signal handling for graceful shutdown
cleanup() {
  echo "Received shutdown signal, stopping services gracefully..."
  
  # Stop nginx gracefully
  if command -v nginx >/dev/null 2>&1; then
    echo "Stopping nginx..."
    nginx -s quit 2>/dev/null || nginx -s stop 2>/dev/null || true
  fi
  
  # Stop PHP-FPM gracefully
  if command -v php-fpm >/dev/null 2>&1; then
    echo "Stopping PHP-FPM..."
    pkill -QUIT php-fpm 2>/dev/null || pkill -TERM php-fpm 2>/dev/null || true
  fi
  
  # Stop any PHP artisan serve processes
  pkill -f "artisan serve" 2>/dev/null || true
  
  echo "Services stopped gracefully"
  exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Start services
echo "Starting PHP-FPM..."
php-fpm --daemonize --fpm-config /usr/local/etc/php-fpm.conf 2>/dev/null || php-fpm -D || php-fpm -D || {
  echo "ERROR: PHP-FPM failed to start. Check configuration and logs."
  exit 1
}

# Configure and start Nginx
{{- include "coolify.container.nginxConfig" . | nindent 0 }}

echo "Starting Nginx in background..."
nginx 2>/dev/null && {
  echo "Nginx started successfully"
  # Keep the script running and handle signals
  while true; do
    sleep 10 &
    wait $!
  done
} || {
  echo "Nginx failed to start, trying to start PHP built-in server as fallback..."
  cd /var/www/html
  echo "Starting PHP built-in server..."
  php artisan serve --host=0.0.0.0 --port={{ .Values.coolifyApp.service.targetPort }} &
  ARTISAN_PID=$!
  echo "PHP artisan serve started with PID $ARTISAN_PID"
  
  # Wait for the artisan serve process
  wait $ARTISAN_PID
}
{{- end -}}

{{/*
PHP-FPM configuration function
*/}}
{{- define "coolify.container.phpFpmConfig" -}}
# Function to configure PHP-FPM before starting
configure_phpfpm() {
  echo "Configuring PHP-FPM in main container..."
  
  # Search for all PHP-FPM configuration files
  echo "Searching for PHP-FPM configuration files..."
  
  # Main PHP-FPM config files - ensure they include pool directory
  for php_fpm_conf in \
    "/usr/local/etc/php-fpm.conf" \
    "/etc/php-fpm.conf" \
    "/etc/php/8.2/fpm/php-fpm.conf" \
    "/etc/php/8.1/fpm/php-fpm.conf" \
    "/etc/php/8.0/fpm/php-fpm.conf" \
    "/etc/php/7.4/fpm/php-fpm.conf"; do
    
    if [ -f "$php_fpm_conf" ]; then
      echo "Found main PHP-FPM config: $php_fpm_conf"
      
      # Ensure include directive points to pool directory
      if ! grep -q "^include.*pool\.d" "$php_fpm_conf"; then
        # Check if any include directive exists and update it, otherwise append
        if grep -q "^include=" "$php_fpm_conf"; then
          sed -i 's|^include=.*|include=/usr/local/etc/php-fpm.d/*.conf|' "$php_fpm_conf"
        else
          echo "include=/usr/local/etc/php-fpm.d/*.conf" >> "$php_fpm_conf"
        fi
      fi
    fi
  done
  
  # Pool configuration files
  POOL_CONFIGURED=false
  for pool_dir in \
    "/usr/local/etc/php-fpm.d" \
    "/etc/php-fpm.d" \
    "/etc/php/8.2/fpm/pool.d" \
    "/etc/php/8.1/fpm/pool.d" \
    "/etc/php/8.0/fpm/pool.d" \
    "/etc/php/7.4/fpm/pool.d"; do
    
    echo "Checking pool directory: $pool_dir"
    
    if [ -d "$pool_dir" ]; then
      echo "Found pool directory: $pool_dir"
      pool_conf="$pool_dir/www.conf"
      
      # Create or update pool configuration
      echo "Configuring pool: $pool_conf"
      echo '[www]' > "$pool_conf"
      echo 'user = www-data' >> "$pool_conf"
      echo 'group = www-data' >> "$pool_conf"
      echo 'listen = 127.0.0.1:9000' >> "$pool_conf"
      echo 'listen.owner = www-data' >> "$pool_conf"
      echo 'listen.group = www-data' >> "$pool_conf"
      echo 'listen.mode = 0660' >> "$pool_conf"
      echo 'pm = {{ .Values.coolifyApp.php.fpmPmControl | default "dynamic" }}' >> "$pool_conf"
      echo 'pm.max_children = {{ .Values.coolifyApp.php.fpmPmMaxChildren | default "20" }}' >> "$pool_conf"
      echo 'pm.start_servers = {{ .Values.coolifyApp.php.fpmPmStartServers | default "2" }}' >> "$pool_conf"
      echo 'pm.min_spare_servers = {{ .Values.coolifyApp.php.fpmPmMinSpareServers | default "1" }}' >> "$pool_conf"
      echo 'pm.max_spare_servers = {{ .Values.coolifyApp.php.fpmPmMaxSpareServers | default "3" }}' >> "$pool_conf"
      echo 'pm.max_requests = {{ .Values.coolifyApp.php.fpmPmMaxRequests | default "500" }}' >> "$pool_conf"
      echo 'php_admin_value[memory_limit] = {{ .Values.coolifyApp.php.memoryLimit | default "256M" }}' >> "$pool_conf"
      echo 'php_admin_value[error_log] = /var/log/php-fpm/www-error.log' >> "$pool_conf"
      echo 'php_admin_flag[log_errors] = on' >> "$pool_conf"
      POOL_CONFIGURED=true
      break
    elif mkdir -p "$pool_dir" 2>/dev/null; then
      POOL_CONFIGURED=true
      break
    fi
  done
  
  if [ "$POOL_CONFIGURED" = "false" ]; then
    echo "Warning: Could not configure PHP-FPM pool"
    find /usr/local/etc /etc -name "*php*" -type d 2>/dev/null || true
  fi
  
  # Ensure logs directory exists and is writable
  mkdir -p /var/log/php-fpm /var/run/php
  chown -R www-data:www-data /var/log/php-fpm /var/run/php 2>/dev/null || {
    echo "Warning: Could not set ownership for PHP-FPM directories. This may cause logging issues."
  }
  
  echo "=== PHP-FPM Configuration Summary ==="
  echo "PHP-FPM configuration files found:"
  find /usr/local/etc /etc -name "*php-fpm*" -type f 2>/dev/null | head -10 || true
}
{{- end -}}

{{/*
Nginx configuration
*/}}
{{- define "coolify.container.nginxConfig" -}}
# Configure Nginx if available
if command -v nginx >/dev/null 2>&1; then
  echo "Configuring Nginx..."
  
  # Create nginx config
  cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    
    server {
        listen {{ .Values.coolifyApp.service.targetPort }};
        root /var/www/html/public;
        index index.php;
        
        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }
        
        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            # FastCGI parameters
            fastcgi_param  QUERY_STRING       $query_string;
            fastcgi_param  REQUEST_METHOD     $request_method;
            fastcgi_param  CONTENT_TYPE       $content_type;
            fastcgi_param  CONTENT_LENGTH     $content_length;
            fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
            fastcgi_param  REQUEST_URI        $request_uri;
            fastcgi_param  DOCUMENT_URI       $document_uri;
            fastcgi_param  DOCUMENT_ROOT      $document_root;
            fastcgi_param  SERVER_PROTOCOL    $server_protocol;
            fastcgi_param  REQUEST_SCHEME     $scheme;
            fastcgi_param  HTTPS              $https if_not_empty;
            fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
            fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;
            fastcgi_param  REMOTE_ADDR        $remote_addr;
            fastcgi_param  REMOTE_PORT        $remote_port;
            fastcgi_param  SERVER_ADDR        $server_addr;
            fastcgi_param  SERVER_PORT        $server_port;
            fastcgi_param  SERVER_NAME        $server_name;
            fastcgi_param  REDIRECT_STATUS    200;
        }
        
        location ~ /\.ht {
            deny all;
        }
    }
}
EOF
  
  # Test nginx configuration
  if nginx -t 2>/dev/null; then
    echo "Nginx configuration is valid"
  else
    echo "ERROR: nginx configuration test failed"
    nginx -t
  fi
else
  echo "ERROR: nginx binary not found"
fi
{{- end -}}

{{/*
Container security context
*/}}
{{- define "coolify.container.securityContext" -}}
{{- if .Values.securityContext.enabled }}
securityContext:
  runAsUser: {{ .Values.securityContext.runAsUser }}
  runAsGroup: {{ .Values.securityContext.runAsGroup }}
  allowPrivilegeEscalation: {{ .Values.securityContext.allowPrivilegeEscalation }}
  readOnlyRootFilesystem: {{ .Values.securityContext.readOnlyRootFilesystem }}
  {{- if .Values.securityContext.capabilities }}
  capabilities:
    {{- toYaml .Values.securityContext.capabilities | nindent 4 }}
  {{- end }}
{{- else }}
# Main container requires root access for:
# - Creating www-data user (addgroup, adduser)
# - Setting file ownership (chown)  
# - Configuring PHP-FPM and nginx at runtime
# - Running 'su' commands to execute Laravel commands as www-data
# When securityContext.enabled=false, we still run as root for compatibility
securityContext:
  runAsUser: 0
  runAsGroup: 0
  allowPrivilegeEscalation: true
  readOnlyRootFilesystem: false
  capabilities:
    drop:
      - ALL
    add:
      - CHOWN
      - SETUID
      - SETGID
      - DAC_OVERRIDE
      - FOWNER
      - SETPCAP
{{- end }}
{{- end -}}

{{/*
Container health checks
*/}}
{{- define "coolify.container.healthChecks" -}}
{{- if .Values.coolifyApp.healthCheck.enabled }}
readinessProbe:
  httpGet:
    path: {{ .Values.coolifyApp.healthCheck.path | default "/" }}
    port: {{ .Values.coolifyApp.service.targetPort }}
  initialDelaySeconds: {{ .Values.coolifyApp.healthCheck.initialDelaySeconds | default 30 }}
  periodSeconds: {{ .Values.coolifyApp.healthCheck.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.coolifyApp.healthCheck.timeoutSeconds | default 2 }}
  failureThreshold: {{ .Values.coolifyApp.healthCheck.failureThreshold | default 10 }}
  successThreshold: {{ .Values.coolifyApp.healthCheck.successThreshold | default 1 }}
livenessProbe:
  httpGet:
    path: {{ .Values.coolifyApp.healthCheck.path | default "/" }}
    port: {{ .Values.coolifyApp.service.targetPort }}
  initialDelaySeconds: {{ add (.Values.coolifyApp.healthCheck.initialDelaySeconds | default 30) 60 }}
  periodSeconds: {{ .Values.coolifyApp.healthCheck.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.coolifyApp.healthCheck.timeoutSeconds | default 2 }}
  failureThreshold: 3
{{- end }}
{{- end -}}

{{/*
Container resources
*/}}
{{- define "coolify.container.resources" -}}
resources:
  {{- toYaml .Values.coolifyApp.resources | nindent 2 }}
{{- end -}}

{{/*
Pod security context
*/}}
{{- define "coolify.pod.securityContext" -}}
{{- if .Values.securityContext.enabled }}
securityContext:
  runAsUser: {{ .Values.securityContext.runAsUser }}
  runAsGroup: {{ .Values.securityContext.runAsGroup }}
  fsGroup: {{ .Values.securityContext.fsGroup }}
  runAsNonRoot: {{ .Values.securityContext.runAsNonRoot }}
  {{- if .Values.securityContext.seccompProfile }}
  seccompProfile:
    {{- toYaml .Values.securityContext.seccompProfile | nindent 4 }}
  {{- end }}
{{- else }}
securityContext:
  runAsUser: 0
  runAsGroup: 0
  fsGroup: 0
  runAsNonRoot: false
{{- end }}
{{- end -}}

{{/*
Pod volumes
*/}}
{{- define "coolify.pod.volumes" -}}
volumes:
  - name: shared-data
    persistentVolumeClaim:
      claimName: {{ include "coolify.sharedPvc.name" . }}
{{- end -}}
