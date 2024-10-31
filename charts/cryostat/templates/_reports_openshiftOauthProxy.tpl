{{/*
Create OpenShift OAuth Proxy container.
*/}}
{{- define "cryostat.reportsOpenshiftOauthProxy" -}}
- name: {{ printf "%s-%s" .Chart.Name "authproxy" }}
  securityContext:
    {{- toYaml .Values.openshiftOauthProxy.securityContext | nindent 4 }}
  image: "{{ .Values.openshiftOauthProxy.image.repository }}:{{ .Values.openshiftOauthProxy.image.tag }}"
  env:
    - name: COOKIE_SECRET
      valueFrom:
        secretKeyRef:
          name: {{ default (printf "%s-cookie-secret" .Release.Name) .Values.authentication.cookieSecretName }}
          key: COOKIE_SECRET
          optional: false
  args:
    - --pass-access-token=false
    - --pass-user-bearer-token=false
    - --pass-basic-auth=false
    - --htpasswd-file=/etc/oauth2_proxy/basicauth/htpasswd
    - --upstream=http://localhost:10001/
    - --cookie-secret=$(COOKIE_SECRET)
    - --request-logging=true
    - --openshift-service-account={{ include "cryostat.serviceAccountName" . }}
    - --proxy-websockets=true
    - --http-address=0.0.0.0:4180
    - --https-address=:8443
    - --tls-cert=/etc/tls/private/tls.crt
    - --tls-key=/etc/tls/private/tls.key
    - --proxy-prefix=/oauth2
    - --bypass-auth-for=^/health(/liveness)?$
  imagePullPolicy: {{ .Values.openshiftOauthProxy.image.pullPolicy }}
  ports:
    - containerPort: 4180
      name: http
      protocol: TCP
    - containerPort: 8443
      name: https
      protocol: TCP
  resources:
    {{- toYaml .Values.openshiftOauthProxy.resources | nindent 4 }}
  volumeMounts:
    - name: {{ .Release.Name }}-proxy-tls
      mountPath: /etc/tls/private
    - name: {{ .Release.Name }}-reports-secret
      mountPath: /etc/oauth2_proxy/basicauth
      readOnly: true
  terminationMessagePath: /dev/termination-log
  terminationMessagePolicy: File
{{- end}}
