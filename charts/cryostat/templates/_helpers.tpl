{{/*
Expand the name of the chart.
*/}}
{{- define "cryostat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cryostat.fullname" -}}
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
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cryostat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "cryostat.labels" -}}
helm.sh/chart: {{ include "cryostat.chart" . }}
{{ include "cryostat.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "cryostat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cryostat.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: cryostat
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "cryostat.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cryostat.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Cryostat service TLS enablement. Returns the string values "true" or "false".
*/}}
{{- define "cryostat.core.service.tls" -}}
{{ or .Values.authentication.openshift.enabled .Values.oauth2Proxy.tls.selfSigned.enabled ((include "cryostat.certManager.enabled" .) | eq "true") }}
{{- end }}

{{/*
Cryostat service protocol. HTTPS if TLS is enabled, HTTP otherwise.
*/}}
{{- define "cryostat.core.service.scheme" -}}
{{ ternary "https" "http" ( include "cryostat.core.service.tls" . | eq "true" ) }}
{{- end }}

{{/*
Cryostat service port. 8443 if TLS is enabled, 8080 otherwise.
*/}}
{{- define "cryostat.core.service.port" -}}
{{ ternary 8443 8080 ( ( include "cryostat.core.service.scheme" . ) | eq "https" ) }}
{{- end }}

{{/*
Resolve the Cryostat audit logging setting.
If explicitly configured, use it.
If an existing deployment already has the audit env var, preserve its value.
Otherwise default new installs to true.
*/}}
{{- define "cryostat.core.audit.enabled" -}}
{{- $auditMode := .Values.core.audit.mode | toString -}}
{{- if eq $auditMode "enabled" -}}
true
{{- else if eq $auditMode "disabled" -}}
false
{{- else -}}
{{- $existingDeployment := lookup "apps/v1" "Deployment" .Release.Namespace (include "cryostat.deploymentName" .) -}}
{{- if $existingDeployment -}}
{{- $existingAudit := dict "value" "" -}}
{{- range $container := $existingDeployment.spec.template.spec.containers -}}
{{- if eq $container.name $.Chart.Name -}}
{{- range $env := $container.env -}}
{{- if eq $env.name "CRYOSTAT_AUDIT_ENABLED" -}}
{{- $_ := set $existingAudit "value" ($env.value | toString) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- get $existingAudit "value" -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Image reference separator. Returns ":" for tag-based references or "@" for hash-based references.
Automatically detects hash references by checking if the tag starts with a hash algorithm prefix.
Usage: {{ include "cryostat.imageSeparator" .Values.core.image.tag }}
*/}}
{{- define "cryostat.imageSeparator" -}}
{{- $tag := default "" . -}}
{{- if regexMatch "^sha[0-9]{3,}:" $tag -}}
@
{{- else -}}
:
{{- end -}}
{{- end }}

{{/*
Check if the database secret contains a username.
*/}}
{{- define "cryostat.databaseSecretHasUsernameKey" -}}
{{- if empty .Values.core.databaseSecretName -}}
{{ "false" -}}
{{- else -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.core.databaseSecretName ) -}}
{{ not (empty (($secret).data).USERNAME) -}}
{{- end -}}
{{- end -}}

{{/*
Get or generate a default connection key for database.
*/}}
{{- define "cryostat.databaseConnectionKey" -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-db" .Release.Name)) -}}
{{- if $secret -}}
{{/*
   Use current key. Do not regenerate.
*/}}
{{- $secret.data.CONNECTION_KEY -}}
{{- else -}}
{{/*
    Generate new key.
*/}}
{{- (randAlphaNum 32) | b64enc | quote -}}
{{- end -}}
{{- end -}}

{{/*
Get or generate a default encryption key for database.
*/}}
{{- define "cryostat.databaseEncryptionKey" -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-db" .Release.Name)) -}}
{{- if $secret -}}
{{/*
   Use current key. Do not regenerate.
*/}}
{{- $secret.data.ENCRYPTION_KEY -}}
{{- else -}}
{{/*
    Generate new key
*/}}
{{- (randAlphaNum 32) | b64enc | quote -}}
{{- end -}}
{{- end -}}

{{/*
Get or generate a default secret key for object storage.
*/}}
{{- define "cryostat.objectStorageSecretKey" -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-storage-secret" .Release.Name)) -}}
{{- if $secret -}}
{{/*
   Use current secret. Do not regenerate.
*/}}
{{- $secret.data.STORAGE_ACCESS_KEY -}}
{{- else -}}
{{/*
    Generate new secret
*/}}
{{- (randAlphaNum 32) | b64enc | quote -}}
{{- end -}}
{{- end -}}

{{/*
Get or generate a default secret password key for report generators.
*/}}
{{- define "cryostat.reportsPassSecretKey" -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-reports-secret" .Release.Name)) -}}
{{- if $secret -}}
{{/*
   Use current secret. Do not regenerate.
*/}}
{{- $secret.data.REPORTS_PASS -}}
{{- else -}}
{{/*
    Generate new secret
*/}}
{{- (randAlphaNum 32) -}}
{{- end -}}
{{- end -}}

{{/*
Get or generate a default secret key for auth proxy cookies.
*/}}
{{- define "cryostat.cookieSecret" -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-cookie-secret" .Release.Name)) -}}
{{- if $secret -}}
{{/*
   Use current secret. Do not regenerate.
*/}}
{{- $secret.data.COOKIE_SECRET -}}
{{- else -}}
{{/*
    Generate new secret
*/}}
{{- (randAlphaNum 32) | b64enc -}}
{{- end -}}
{{- end -}}

{{/*
    Get sanitized list or defaults (if not disabled) as comma-separated list.
*/}}
{{- define "cryostat.commaSepList" -}}
{{- $l := index . 0 -}}
{{- $default := index . 1 -}}
{{- $disableDefaults := index . 2 -}}
{{- if and (not $l) (not $disableDefaults) -}}
{{- $l = list $default -}}
{{- end -}}
{{- join "," (default list $l | compact | uniq) | quote -}}
{{- end -}}

{{/*
Get the name for managed deployments.
*/}}
{{- define "cryostat.deploymentName" -}}
{{- $version := semver .Chart.AppVersion -}}
{{- printf "%s-v%d" (include "cryostat.fullname" .) $version.Major -}}
{{- end -}}

{{/*
Check if cert-manager integration is enabled. Returns the string values "true" or "false".
*/}}
{{- define "cryostat.certManager.enabled" -}}
{{- .Values.tls.certManager.enabled | toString -}}
{{- end -}}

{{/*
Get issuer reference for cert-manager. Returns issuer configuration or defaults to self-signed issuer.
*/}}
{{- define "cryostat.certManager.issuerRef" -}}
{{- if .Values.tls.certManager.issuerRef.name -}}
name: {{ .Values.tls.certManager.issuerRef.name }}
kind: {{ .Values.tls.certManager.issuerRef.kind | default "Issuer" }}
group: {{ .Values.tls.certManager.issuerRef.group | default "cert-manager.io" }}
{{- else -}}
name: {{ .Release.Name }}-selfsigned-issuer
kind: Issuer
group: cert-manager.io
{{- end -}}
{{- end -}}

{{/*
Determine if TLS should be enabled (cert-manager OR existing methods). Returns boolean.
*/}}
{{- define "cryostat.tls.enabled" -}}
{{- or .Values.tls.certManager.enabled .Values.authentication.openshift.enabled .Values.oauth2Proxy.tls.selfSigned.enabled -}}
{{- end -}}

{{/*
Generate JDBC URL for database connection with optional TLS parameters.
*/}}
{{- define "cryostat.db.jdbcUrl" -}}
{{- $fullName := include "cryostat.fullname" . -}}
{{- $baseUrl := default (printf "jdbc:postgresql://%s-db:5432/cryostat" $fullName) .Values.db.provider.url -}}
{{- if (include "cryostat.certManager.enabled" .) | eq "true" -}}
{{- if not (contains "?" $baseUrl) -}}
{{- printf "%s?ssl=true&sslmode=verify-full&sslcert=&sslrootcert=/etc/database-tls/ca.crt" $baseUrl -}}
{{- else -}}
{{- printf "%s&ssl=true&sslmode=verify-full&sslcert=&sslrootcert=/etc/database-tls/ca.crt" $baseUrl -}}
{{- end -}}
{{- else -}}
{{- $baseUrl -}}
{{- end -}}
{{- end }}

{{/*
Generate S3 storage endpoint URL with appropriate scheme (http/https).
*/}}
{{- define "cryostat.storage.endpointUrl" -}}
{{- if .Values.storage.provider.url -}}
{{- .Values.storage.provider.url -}}
{{- else -}}
{{- $fullName := include "cryostat.fullname" . -}}
{{- $scheme := ternary "https" "http" ((include "cryostat.certManager.enabled" .) | eq "true") -}}
{{- printf "%s://%s-storage:8333" $scheme $fullName -}}
{{- end -}}
{{- end }}

{{/*
Get the secret name for TLS certificates based on cert-manager or legacy mode.
For cryostat main service.
*/}}
{{- define "cryostat.tls.cryostat.secretName" -}}
{{- if (include "cryostat.certManager.enabled" .) | eq "true" -}}
{{- printf "%s-cryostat-tls" .Release.Name -}}
{{- else if .Values.authentication.openshift.enabled -}}
{{- printf "%s-proxy-tls" .Release.Name -}}
{{- else -}}
{{- printf "%s-oauth2proxy-tls" .Release.Name -}}
{{- end -}}
{{- end }}

{{/*
Get the secret name for TLS certificates for reports service.
*/}}
{{- define "cryostat.tls.reports.secretName" -}}
{{- if (include "cryostat.certManager.enabled" .) | eq "true" -}}
{{- printf "%s-reports-tls" .Release.Name -}}
{{- else if .Values.authentication.openshift.enabled -}}
{{- printf "%s-proxy-tls" .Release.Name -}}
{{- else -}}
{{- printf "%s-oauth2proxy-reports-tls" .Release.Name -}}
{{- end -}}
{{- end }}

{{/*
Get the secret name for database TLS certificates.
*/}}
{{- define "cryostat.tls.db.secretName" -}}
{{- printf "%s-db-tls" .Release.Name -}}
{{- end }}

{{/*
Get the secret name for storage TLS certificates.
*/}}
{{- define "cryostat.tls.storage.secretName" -}}
{{- printf "%s-storage-tls" .Release.Name -}}
{{- end -}}

{{/*
Get the reports upstream URL. Always HTTP since TLS termination is on the auth proxy.
*/}}
{{- define "cryostat.reports.upstreamUrl" -}}
http://localhost:10001/
{{- end -}}
