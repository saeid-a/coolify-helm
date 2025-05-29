{{/*
Init container for setting up storage directories and permissions
*/}}
{{- define "coolify.initContainer.setupStorage" -}}
- name: setup-storage
  image: "{{ .Values.coolifyApp.image.repository }}:{{ .Values.coolifyApp.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.coolifyApp.image.pullPolicy | default "IfNotPresent" }}
  command: ["/bin/sh"]
  args:
    - -c
    - |
      echo "Setting up storage directories and permissions..."
      
      # Create all required directories
      mkdir -p /var/www/html/storage/app/ssh/keys
      mkdir -p /var/www/html/storage/app/applications
      mkdir -p /var/www/html/storage/app/databases  
      mkdir -p /var/www/html/storage/app/services
      mkdir -p /var/www/html/storage/app/backups
      mkdir -p /var/www/html/storage/app/webhooks-during-maintenance
      mkdir -p /var/www/html/storage/logs
      mkdir -p /var/www/html/storage/framework/cache
      mkdir -p /var/www/html/storage/framework/sessions
      mkdir -p /var/www/html/storage/framework/views
      mkdir -p /var/www/html/bootstrap/cache
      
      # Set proper permissions (Laravel needs 775 for storage)
      chmod -R 775 /var/www/html/storage
      chmod -R 775 /var/www/html/bootstrap/cache
      
      # Ensure www-data user owns the directories
      chown -R www-data:www-data /var/www/html/storage
      chown -R www-data:www-data /var/www/html/bootstrap/cache
      
      echo "Storage setup completed successfully"
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
  {{- include "coolify.initContainer.securityContext" . | nindent 2 }}
  resources:
    {{- toYaml .Values.coolifyApp.initContainers.setupStorage.resources | nindent 4 }}
{{- end -}}

{{/*
Init container for database migration
*/}}
{{- define "coolify.initContainer.databaseMigration" -}}
{{- if .Values.coolifyApp.migration.enabled }}
- name: migrate-database
  image: "{{ .Values.coolifyApp.image.repository }}:{{ .Values.coolifyApp.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.coolifyApp.image.pullPolicy | default "IfNotPresent" }}
  command: ["/bin/sh"]
  args:
    - -c
    - |
      echo "Starting database migration..."
      
      # Set maximum wait time (5 minutes)
      MAX_WAIT_TIME=300
      WAIT_INTERVAL=5
      ELAPSED_TIME=0
      
      # Wait for database to be ready
      echo "Waiting for database to be ready..."
      
      # Debug environment variables
      echo "Debug: DB_HOST=${DB_HOST}"
      echo "Debug: DB_PORT=${DB_PORT}" 
      echo "Debug: DB_DATABASE=${DB_DATABASE}"
      echo "Debug: DB_USERNAME=${DB_USERNAME}"
      echo "Debug: Connection string will be: pgsql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_DATABASE}"
      
      # Test database connection with better error handling
      until php -r "
        \$host = getenv('DB_HOST');
        \$port = getenv('DB_PORT') ?: '5432';
        \$dbname = getenv('DB_DATABASE');
        \$username = getenv('DB_USERNAME');
        \$password = getenv('DB_PASSWORD');
        
        echo 'Environment check:' . PHP_EOL;
        echo '  DB_HOST: ' . (\$host ?: '(empty)') . PHP_EOL;
        echo '  DB_PORT: ' . \$port . PHP_EOL;
        echo '  DB_DATABASE: ' . (\$dbname ?: '(empty)') . PHP_EOL;
        echo '  DB_USERNAME: ' . (\$username ?: '(empty)') . PHP_EOL;
        echo '  DB_PASSWORD: ' . (empty(\$password) ? '(empty)' : '(set)') . PHP_EOL;
        
        if (empty(\$host)) {
          echo 'ERROR: DB_HOST is empty' . PHP_EOL;
          exit(1);
        }
        if (empty(\$dbname)) {
          echo 'ERROR: DB_DATABASE is empty' . PHP_EOL;
          exit(1);
        }
        if (empty(\$username)) {
          echo 'ERROR: DB_USERNAME is empty' . PHP_EOL;
          exit(1);
        }
        
        \$dsn = 'pgsql:host=' . \$host . ';port=' . \$port . ';dbname=' . \$dbname;
        echo 'Attempting connection with DSN: ' . \$dsn . PHP_EOL;
        
        try {
          \$pdo = new PDO(\$dsn, \$username, \$password, [
            PDO::ATTR_TIMEOUT => 5,
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
          ]);
          echo 'Database connection successful!' . PHP_EOL;
          exit(0);
        } catch (PDOException \$e) {
          echo 'Database connection failed: ' . \$e->getMessage() . PHP_EOL;
          exit(1);
        }
      "; do
        ELAPSED_TIME=$((ELAPSED_TIME + WAIT_INTERVAL))
        if [ $ELAPSED_TIME -ge $MAX_WAIT_TIME ]; then
          echo "Timeout: Database did not become ready after ${MAX_WAIT_TIME} seconds"
          exit 1
        fi
        echo "Database not ready, waiting ${WAIT_INTERVAL} seconds... (${ELAPSED_TIME}/${MAX_WAIT_TIME}s elapsed)"
        sleep $WAIT_INTERVAL
      done
      
      echo "Database is ready, running migrations..."
      
      # Ensure proper permissions for Laravel
      chown -R www-data:www-data /var/www/html/storage
      chown -R www-data:www-data /var/www/html/bootstrap/cache
      
      # Run Laravel cache clear and config cache as www-data
      su -s /bin/sh www-data -c "php artisan config:clear" || echo "Config clear failed, continuing..."
      su -s /bin/sh www-data -c "php artisan cache:clear" || echo "Cache clear failed, continuing..."
      su -s /bin/sh www-data -c "php artisan route:clear" || echo "Route clear failed, continuing..."
      su -s /bin/sh www-data -c "php artisan view:clear" || echo "View clear failed, continuing..."
      
      # Run database migrations as www-data
      su -s /bin/sh www-data -c "php artisan migrate --force --no-interaction"
      
      # Optimize Laravel application for production
      echo "Optimizing Laravel application..."
      su -s /bin/sh www-data -c "php artisan config:cache" || echo "Config cache failed, continuing..."
      su -s /bin/sh www-data -c "php artisan route:cache" || echo "Route cache failed, continuing..."
      su -s /bin/sh www-data -c "php artisan view:cache" || echo "View cache failed, continuing..."
      
      # Create storage link
      su -s /bin/sh www-data -c "php artisan storage:link" || echo "Storage link failed, continuing..."
      
      {{- if .Values.coolifyApp.migration.runSeeders }}
      # Run database seeders as www-data
      echo "Running database seeders..."
      su -s /bin/sh www-data -c "php artisan db:seed --force --no-interaction"
      {{- end }}
      
      echo "Database migration completed successfully"
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
  workingDir: /var/www/html
  {{- include "coolify.initContainer.securityContext" . | nindent 2 }}
  resources:
    {{- toYaml .Values.coolifyApp.initContainers.migration.resources | nindent 4 }}
{{- end }}
{{- end -}}

{{/*
Security context for init containers that need root access
*/}}
{{- define "coolify.initContainer.securityContext" -}}
securityContext:
  # Init containers need root for setup permissions, regardless of global settings
  runAsUser: 0  # Run as root to set permissions
  runAsGroup: 0
  {{- if .Values.securityContext.enabled }}
  allowPrivilegeEscalation: {{ .Values.securityContext.allowPrivilegeEscalation }}
  readOnlyRootFilesystem: {{ .Values.securityContext.readOnlyRootFilesystem }}
  {{- if .Values.securityContext.capabilities }}
  capabilities:
    {{- toYaml .Values.securityContext.capabilities | nindent 4 }}
  {{- end }}
  {{- else }}
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  capabilities:
    drop:
      - ALL
  {{- end }}
{{- end -}}
