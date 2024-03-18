{{- define "openshiftOauthProxy" }}
- name: {{ printf "%s-%s" .Chart.Name "authproxy" }}
  securityContext:
    {{- toYaml .Values.openshiftOauthProxy.securityContext | nindent 12 }}
  image: "{{ .Values.openshiftOauthProxy.image.repository }}:{{ .Values.openshiftOauthProxy.image.tag }}"
  args:
    - --upstream=http://localhost:8181/
    - --upstream=http://localhost:3000/grafana/
    - --upstream=http://localhost:8333/storage/
    - --cookie-secret={{ include "cryostat.cookieSecret" . }}
    - --openshift-service-account={{ include "cryostat.serviceAccountName" . }}
    - --proxy-websockets=true
    - --http-address=0.0.0.0:4180
    - --https-address=:8443
    - --tls-cert=/etc/tls/private/tls.crt
    - --tls-key=/etc/tls/private/tls.key
    {{- if .Values.authentication.basicAuth.enabled }}
    - --htpasswd-file=/etc/openshift_oauth_proxy/basicauth
    {{- end }}
    - --request-logging=true
  imagePullPolicy: {{ .Values.openshiftOauthProxy.image.pullPolicy }}
  ports:
    - containerPort: 4180
      protocol: TCP
  volumeMounts:
    {{- if .Values.authentication.basicAuth.enabled }}
    - name: {{ .Release.Name }}-htpasswd
      mountPath: /etc/openshift_oauth_proxy/basicauth
      readOnly: true
    {{- end }}
    - name: {{ .Release.Name }}-proxy-tls
      mountPath: /etc/tls/private
  resources: {}
  terminationMessagePath: /dev/termination-log
  terminationMessagePolicy: File
{{- end}}
