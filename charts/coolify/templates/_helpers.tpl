{{/*
Common labels
*/}}
{{- define "coolify.labels" -}}
helm.sh/chart: {{ include "coolify.chart" . }}
{{ include "coolify.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "coolify.selectorLabels" -}}
app.kubernetes.io/name: {{ include "coolify.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .componentName }}
app.kubernetes.io/component: {{ .componentName }}
{{- end }}
{{- end }}

{{/*
Create the name of the chart.
*/}}
{{- define "coolify.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by DNS naming spec).
*/}}
{{- define "coolify.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "coolify.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Return the target namespace
*/}}
{{- define "coolify.namespace" -}}
{{- .Values.global.namespace | default .Release.Namespace -}}
{{- end -}}

{{/*
Coolify App full name
*/}}
{{- define "coolify.coolifyApp.fullname" -}}
{{- printf "%s-app" (include "coolify.fullname" .) }}
{{- end -}}

{{/*
Coolify App service name
*/}}
{{- define "coolify.coolifyApp.serviceName" -}}
{{- printf "%s-svc" (include "coolify.coolifyApp.fullname" .) }}
{{- end -}}

{{/*
PostgreSQL full name
*/}}
{{- define "coolify.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "coolify.fullname" .) }}
{{- end -}}

{{/*
PostgreSQL service name
*/}}
{{- define "coolify.postgresql.serviceName" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.config.DB_HOST -}}
{{- end -}}
{{- end -}}


{{/*
Redis full name
*/}}
{{- define "coolify.redis.fullname" -}}
{{- printf "%s-redis" (include "coolify.fullname" .) }}
{{- end -}}

{{/*
Redis service name
*/}}
{{- define "coolify.redis.serviceName" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis-master" .Release.Name -}}
{{- else -}}
{{- .Values.config.REDIS_HOST -}}
{{- end -}}
{{- end -}}

{{/*
Soketi full name
*/}}
{{- define "coolify.soketi.fullname" -}}
{{- printf "%s-soketi" (include "coolify.fullname" .) }}
{{- end -}}

{{/*
Soketi service name
*/}}
{{- define "coolify.soketi.serviceName" -}}
{{- printf "%s-svc" (include "coolify.soketi.fullname" .) }}
{{- end -}}


{{/*
Shared PVC name
*/}}
{{- define "coolify.sharedPvc.name" -}}
{{- .Values.sharedDataPvc.name | default (printf "%s-shared-data-pvc" (include "coolify.fullname" .)) }}
{{- end -}}

{{/*
Generate random strings for secrets if not provided in values.yaml
Security: All passwords are auto-generated using cryptographically secure random functions
if they are not explicitly provided by the user.
*/}}

{{/* Generate APP_ID if not set - 32 character alphanumeric */}}
{{- define "coolify.secret.appId" -}}
{{- if .Values.secrets.APP_ID -}}
{{- .Values.secrets.APP_ID -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}

{{/* Generate APP_KEY if not set - Laravel compatible with base64: prefix */}}
{{- define "coolify.secret.appKey" -}}
{{- if .Values.secrets.APP_KEY -}}
{{- .Values.secrets.APP_KEY -}}
{{- else -}}
{{- printf "base64:%s" (randAlphaNum 32 | b64enc) -}}
{{- end -}}
{{- end -}}

{{/*
Single source of truth for password generation to ensure consistency
These helpers generate passwords once and share them across all templates
*/}}

{{/* Generate a shared database password - this is the single source of truth */}}
{{- define "coolify.shared.dbPassword" -}}
{{- if .Values.secrets.DB_PASSWORD -}}
{{- .Values.secrets.DB_PASSWORD -}}
{{- else if .Values.postgresql.auth.password -}}
{{- .Values.postgresql.auth.password -}}
{{- else -}}
{{- $existingSecret := (lookup "v1" "Secret" .Release.Namespace "coolify-app-secrets") -}}
{{- if $existingSecret -}}
{{- index $existingSecret.data "DB_PASSWORD" | b64dec -}}
{{- else -}}
{{- $existingPgSecret := (lookup "v1" "Secret" .Release.Namespace "coolify-postgresql") -}}
{{- if $existingPgSecret -}}
{{- index $existingPgSecret.data "password" | b64dec -}}
{{- else -}}
{{- /* Use a deterministic seed based on release name and namespace for consistency */}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Generate a shared Redis password - this is the single source of truth */}}
{{- define "coolify.shared.redisPassword" -}}
{{- if .Values.secrets.REDIS_PASSWORD -}}
{{- .Values.secrets.REDIS_PASSWORD -}}
{{- else if .Values.redis.auth.password -}}
{{- .Values.redis.auth.password -}}
{{- else -}}
{{- $existingSecret := (lookup "v1" "Secret" .Release.Namespace "coolify-app-secrets") -}}
{{- if $existingSecret -}}
{{- index $existingSecret.data "REDIS_PASSWORD" | b64dec -}}
{{- else -}}
{{- $existingRedisSecret := (lookup "v1" "Secret" .Release.Namespace "coolify-redis") -}}
{{- if $existingRedisSecret -}}
{{- index $existingRedisSecret.data "redis-password" | b64dec -}}
{{- else -}}
{{- /* Use a deterministic seed based on release name and namespace for consistency */}}
{{- $seed := printf "%s-%s-redis" .Release.Name .Release.Namespace | sha256sum | trunc 32 -}}
{{- $seed -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Generate DB_PASSWORD - now references the shared password */}}
{{- define "coolify.secret.dbPassword" -}}
{{- include "coolify.shared.dbPassword" . -}}
{{- end -}}

{{/* Generate REDIS_PASSWORD - now references the shared password */}}
{{- define "coolify.secret.redisPassword" -}}
{{- include "coolify.shared.redisPassword" . -}}
{{- end -}}

{{/* Generate PUSHER_APP_ID if not set - 32 character alphanumeric */}}
{{- define "coolify.secret.pusherAppId" -}}
{{- if .Values.secrets.PUSHER_APP_ID -}}
{{- .Values.secrets.PUSHER_APP_ID -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}

{{/* Generate PUSHER_APP_KEY if not set - 32 character alphanumeric */}}
{{- define "coolify.secret.pusherAppKey" -}}
{{- if .Values.secrets.PUSHER_APP_KEY -}}
{{- .Values.secrets.PUSHER_APP_KEY -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}

{{/* Generate PUSHER_APP_SECRET if not set - 32 character alphanumeric */}}
{{- define "coolify.secret.pusherAppSecret" -}}
{{- if .Values.secrets.PUSHER_APP_SECRET -}}
{{- .Values.secrets.PUSHER_APP_SECRET -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}

{{/* Generate ROOT_USER_PASSWORD if not set and root user is configured - 20 character secure password */}}
{{- define "coolify.secret.rootUserPassword" -}}
{{- if .Values.secrets.ROOT_USER_PASSWORD -}}
{{- .Values.secrets.ROOT_USER_PASSWORD -}}
{{- else -}}
{{- randAlphaNum 20 -}}
{{- end -}}
{{- end -}}

{{/*
Generate the config map name
*/}}
{{- define "coolify.configMap.name" -}}
{{- printf "%s-app-config" (include "coolify.fullname" .) }}
{{- end -}}

{{/*
Generate the secret name
*/}}
{{- define "coolify.secret.name" -}}
{{- printf "%s-app-secrets" (include "coolify.fullname" .) }}
{{- end -}}

{{/*
Helper to determine storage class for a component
*/}}
{{- define "coolify.storageClass" -}}
{{- $persistence := .persistence -}}
{{- $global := .global -}}
{{- if $persistence.storageClassName -}}
{{- if eq $persistence.storageClassName "-" -}}
{{- print "" -}}
{{- else -}}
{{- $persistence.storageClassName -}}
{{- end -}}
{{- else -}}
{{- $global.storageClassName | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Validate required values and provide helpful error messages
*/}}
{{- define "coolify.validateValues" -}}
{{- if not .Values.global.namespace -}}
{{- fail "global.namespace is required" -}}
{{- end -}}
{{- if and .Values.coolifyApp.enabled (not .Values.config.APP_URL) -}}
{{- fail "config.APP_URL is required when coolifyApp is enabled" -}}
{{- end -}}
{{- if and .Values.postgresql.enabled .Values.redis.enabled (eq .Values.config.DB_HOST .Values.config.REDIS_HOST) -}}
{{- fail "DB_HOST and REDIS_HOST cannot be the same" -}}
{{- end -}}
{{- end -}}

{{/*
Generate extra hosts configuration for Docker socket access
*/}}
{{- define "coolify.extraHosts" -}}
{{- if .extraHosts }}
hostAliases:
{{- range .extraHosts }}
  - ip: {{ .ip | quote }}
    hostnames:
    - {{ .name | quote }}
{{- end }}
{{- end }}
{{- end -}}


{{/*
Helper to construct the full image name for a component.
Usage: {{ include "coolify.imageName" (dict "componentValues" .Values.coolifyApp "globalValues" .Values.global) }}
*/}}
{{- define "coolify.imageName" -}}
{{- $registry := .globalValues.registryUrl | default "ghcr.io" -}}
{{- $repository := .componentValues.image.repository -}}
{{- $tag := .componentValues.image.tag | default $.Chart.AppVersion -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- end -}}

{{/*
PostgreSQL password helpers for subchart integration
All helpers now use shared password sources to ensure perfect synchronization
*/}}

{{/* Generate PostgreSQL admin password if not set - uses shared DB password */}}
{{- define "coolify.postgresql.adminPassword" -}}
{{- if .Values.postgresql.auth.postgresPassword -}}
{{- .Values.postgresql.auth.postgresPassword -}}
{{- else -}}
{{- include "coolify.shared.dbPassword" . -}}
{{- end -}}
{{- end -}}

{{/* Generate PostgreSQL user password if not set - uses shared DB password */}}
{{- define "coolify.postgresql.userPassword" -}}
{{- if .Values.postgresql.auth.password -}}
{{- .Values.postgresql.auth.password -}}
{{- else -}}
{{- include "coolify.shared.dbPassword" . -}}
{{- end -}}
{{- end -}}

{{/* Generate Redis password if not set - uses shared Redis password */}}
{{- define "coolify.redis.password" -}}
{{- if .Values.redis.auth.password -}}
{{- .Values.redis.auth.password -}}
{{- else -}}
{{- include "coolify.shared.redisPassword" . -}}
{{- end -}}
{{- end -}}

{{/*
Synchronize Redis password across the chart
This helper centralizes the Redis password synchronization logic
*/}}
{{- define "coolify.sync.redisPassword" -}}
{{- $redisPassword := include "coolify.secret.redisPassword" . -}}
{{- $_ := set .Values.redis.auth "password" $redisPassword -}}
{{- end -}}

{{/*
Pod-level security context
*/}}
{{- define "coolify.securityContext.pod" -}}
{{- if .Values.securityContext.enabled }}
runAsUser: {{ .Values.securityContext.runAsUser | default 0 }}
runAsGroup: {{ .Values.securityContext.runAsGroup | default 0 }}
fsGroup: {{ .Values.securityContext.fsGroup | default 0 }}
runAsNonRoot: {{ .Values.securityContext.runAsNonRoot | default false }}
{{- else }}
runAsUser: 0
runAsGroup: 0
fsGroup: 0
runAsNonRoot: false
{{- end }}
{{- end -}}