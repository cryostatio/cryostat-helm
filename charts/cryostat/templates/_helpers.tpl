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
{{ or .Values.authentication.openshift.enabled .Values.oauth2Proxy.tls.selfSigned.enabled }}
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
Get or generate a self-signed TLS certificate and private key, reusing the existing Secret's
data if present rather than regenerating a fresh pair on every render. The Secret this backs is
marked immutable, so a render after the first one has to reproduce the same cert and key
exactly, or the Kubernetes API rejects the update outright. Returns a complete "data:" block,
rather than a single value like the chart's other generated secrets, because a certificate and
its key must be looked up and (re)generated together as one pair, not as two independent values
that could otherwise end up mismatched.
Usage: include "cryostat.selfSignedCertData" (dict "namespace" .Release.Namespace "secretName" (printf "%s-oauth2proxy-tls" .Release.Name) "commonName" $fullName)
*/}}
{{- define "cryostat.selfSignedCertData" -}}
{{- $secret := (lookup "v1" "Secret" .namespace .secretName) -}}
{{- if $secret -}}
{{/*
   Use the current cert and key. Do not regenerate.
*/}}
cert: {{ $secret.data.cert }}
key: {{ $secret.data.key }}
{{- else -}}
{{/*
    Generate a new cert and key.
*/}}
{{- $cert := genSelfSignedCert .commonName nil nil 365 -}}
cert: {{ $cert.Cert | b64enc }}
key: {{ $cert.Key | b64enc }}
{{- end -}}
{{- end -}}

{{/*
Get or generate the shared secret that the auth strip proxy stamps onto every request it
forwards to Cryostat. Returns the plaintext value, not a base64 encoding of it, because it is
rendered both as a Secret value and into an nginx directive.

The alphabet matters here for correctness and not only for entropy: nginx interpolates "$"
inside a double-quoted directive value, and "\" and '"' would end or escape it. randAlphaNum
emits only [a-zA-Z0-9], so the rendering in userproxy_secret.yaml is safe. Anything that widens
this alphabet must escape for nginx there.
*/}}
{{- define "cryostat.userProxySecret" -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-user-proxy" .Release.Name)) -}}
{{- $existing := ((($secret).data).USER_PROXY_SECRET | default "" | b64dec) -}}
{{- if $existing -}}
{{/*
   Use current secret. Do not regenerate.
*/}}
{{- $existing -}}
{{- else -}}
{{/*
    Generate new secret
*/}}
{{- (randAlphaNum 32) -}}
{{- end -}}
{{- end -}}

{{/*
Name of the Secret holding the auth strip proxy's shared secret.
*/}}
{{- define "cryostat.userProxySecretName" -}}
{{- default (printf "%s-user-proxy" .Release.Name) .Values.authentication.userProxySecretName -}}
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
Where Grafana's data directory lives when it is on a scratch volume. A subdirectory of
/var/lib/grafana rather than that path itself, which also holds the plugins shipped in the
image and so cannot be covered by a volume.
*/}}
{{- define "cryostat.grafana.scratchPath" -}}
/var/lib/grafana/data
{{- end -}}

{{/*
Whether a component has a scratch volume to mount. Returns the string "true", or the empty
string. A claim template takes precedence over an emptyDir, so that a user who asks for one does
not also have to disable the emptyDir that is enabled by default.
Usage: include "cryostat.scratch.enabled" .Values.core.scratch
*/}}
{{- define "cryostat.scratch.enabled" -}}
{{- $scratch := . | default dict -}}
{{- if not (empty ($scratch.volumeClaimTemplate | default dict)) -}}
true
{{- else if ($scratch.emptyDir).enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Render a component's scratch volume, or nothing if it has none. A claim template becomes a
generic ephemeral volume: capacity comes from a StorageClass rather than the node's overlay
partition, and the volume is created and deleted along with the Pod.
Usage: include "cryostat.scratch.volume" (dict "name" "cryostat-scratch" "scratch" .Values.core.scratch)
*/}}
{{- define "cryostat.scratch.volume" -}}
{{- $scratch := .scratch | default dict -}}
{{- $claimTemplate := $scratch.volumeClaimTemplate | default dict -}}
{{- if not (empty $claimTemplate) -}}
- name: {{ .name }}
  ephemeral:
    volumeClaimTemplate:
      {{- toYaml $claimTemplate | nindent 6 }}
{{- else if ($scratch.emptyDir).enabled -}}
{{- $emptyDir := dict -}}
{{- with ($scratch.emptyDir).medium }}{{- $_ := set $emptyDir "medium" . -}}{{- end -}}
{{- with ($scratch.emptyDir).sizeLimit }}{{- $_ := set $emptyDir "sizeLimit" . -}}{{- end -}}
- name: {{ .name }}
  emptyDir:{{ if $emptyDir }}{{ toYaml $emptyDir | nindent 4 }}{{ else }} {}{{ end }}
{{- end -}}
{{- end -}}

{{/*
Render a mount of a component's scratch volume, or nothing if it has none.
Usage: include "cryostat.scratch.mount" (dict "name" "cryostat-scratch" "scratch" .Values.core.scratch "mountPath" "/tmp" "subPath" "")
*/}}
{{- define "cryostat.scratch.mount" -}}
{{- if eq (include "cryostat.scratch.enabled" .scratch) "true" -}}
- name: {{ .name }}
  mountPath: {{ .mountPath }}
  {{- with .subPath }}
  subPath: {{ . }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/*
Convert a Kubernetes resource quantity to a whole number of bytes. Understands the binary
(Ki, Mi, Gi, Ti, Pi, Ei) and decimal (k, M, G, T, P, E) suffixes, a fractional amount of either
(ex. 0.5Gi), and a bare integer. Returns 0 for anything else.
*/}}
{{- define "cryostat.quantityToBytes" -}}
{{- $quantity := . | toString | trim -}}
{{- $suffixes := list
  (list "Ki" 1024)
  (list "Mi" 1048576)
  (list "Gi" 1073741824)
  (list "Ti" 1099511627776)
  (list "Pi" 1125899906842624)
  (list "Ei" 1152921504606846976)
  (list "k" 1000)
  (list "M" 1000000)
  (list "G" 1000000000)
  (list "T" 1000000000000)
  (list "P" 1000000000000000)
  (list "E" 1000000000000000000) -}}
{{- $bytes := int64 0 -}}
{{- $matched := false -}}
{{- range $suffix := $suffixes -}}
{{- $symbol := index $suffix 0 -}}
{{- $factor := index $suffix 1 -}}
{{- if and (not $matched) (hasSuffix $symbol $quantity) -}}
{{- $digits := trimSuffix $symbol $quantity -}}
{{- if regexMatch "^[0-9]+$" $digits -}}
{{/*
   Whole amount of the suffix: exact integer arithmetic.
*/}}
{{- $matched = true -}}
{{- $bytes = mul (int64 $digits) (int64 $factor) -}}
{{- else if regexMatch "^[0-9]+\\.[0-9]+$" $digits -}}
{{/*
   Fractional amount of the suffix (ex. 0.5Gi): floating-point arithmetic, since the amount
   itself is not a whole number.
*/}}
{{- $matched = true -}}
{{- $bytes = mulf (float64 $digits) (float64 $factor) | int64 -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not $matched -}}
{{- if regexMatch "^[0-9]+$" $quantity -}}
{{- $bytes = int64 $quantity -}}
{{- else if regexMatch "^[0-9]+\\.[0-9]+$" $quantity -}}
{{- $bytes = float64 $quantity | int64 -}}
{{- end -}}
{{- end -}}
{{- $bytes -}}
{{- end -}}

{{/*
The size the Cryostat container's scratch space is bounded to, as a resource quantity, or the
empty string if it is unbounded. A claim template's storage request is preferred and is never
further bounded, since it provisions a separate PersistentVolume rather than counting against the
Pod's ephemeral-storage. Otherwise, the scratch emptyDir's size limit is used; if its medium is
not Memory (so it is backed by local disk, which does count against ephemeral-storage) and the
container also has a smaller ephemeral-storage limit, that smaller limit is used instead, since
the kubelet enforces whichever bound is reached first. With no sized scratch volume at all, any
ephemeral-storage limit on the container is used as-is, since every scratch write then lands on
the container runtime's overlay layer, which that limit bounds directly.
*/}}
{{- define "cryostat.core.scratchSize" -}}
{{- $scratch := .Values.core.scratch | default dict -}}
{{- $claimTemplate := $scratch.volumeClaimTemplate | default dict -}}
{{- $ephemeralLimit := index ((.Values.core.resources).limits | default dict) "ephemeral-storage" | default "" -}}
{{- $size := "" -}}
{{- if not (empty $claimTemplate) -}}
{{- $size = ((($claimTemplate.spec).resources).requests).storage | default "" -}}
{{- else if ($scratch.emptyDir).enabled -}}
{{- $size = ($scratch.emptyDir).sizeLimit | default "" -}}
{{- $medium := ($scratch.emptyDir).medium | default "" -}}
{{- if and $size $ephemeralLimit (ne $medium "Memory") -}}
{{- $sizeBytes := include "cryostat.quantityToBytes" $size | int64 -}}
{{- $limitBytes := include "cryostat.quantityToBytes" $ephemeralLimit | int64 -}}
{{- if lt $limitBytes $sizeBytes -}}
{{- $size = $ephemeralLimit -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not $size -}}
{{- $size = $ephemeralLimit -}}
{{- end -}}
{{- $size -}}
{{- end -}}

{{/*
The weight, in MiB, to cap Cryostat's on-disk JFR analysis cache at, so that its own eviction
bound matches the scratch space actually provisioned. Empty when no bound on that space is
known, in which case Cryostat's built-in default stands.
*/}}
{{- define "cryostat.core.jfrAnalysisCacheMaxWeight" -}}
{{- $size := include "cryostat.core.scratchSize" . -}}
{{- if $size -}}
{{- $bytes := include "cryostat.quantityToBytes" $size | int64 -}}
{{- if gt $bytes (int64 0) -}}
{{- $percentage := (.Values.core.scratch).cachePercentage | default 50 | int64 -}}
{{- div (mul (div $bytes 1048576) $percentage) 100 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get the name for managed deployments.
*/}}
{{- define "cryostat.deploymentName" -}}
{{- $version := semver .Chart.AppVersion -}}
{{- printf "%s-v%d" (include "cryostat.fullname" .) $version.Major -}}
{{- end -}}
