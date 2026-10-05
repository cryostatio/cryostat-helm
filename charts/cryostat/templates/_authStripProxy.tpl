{{/*
Create the auth strip proxy container. This sits between the authenticating proxy and Cryostat:
it re-sources the X-Forwarded-* headers so that they cannot be client-supplied, and stamps the
shared secret that proves to Cryostat which path a request arrived by.
*/}}
{{- define "cryostat.authStripProxy" -}}
- name: {{ printf "%s-%s" .Chart.Name "auth-strip-proxy" }}
  securityContext:
    {{- toYaml .Values.authStripProxy.securityContext | nindent 4 }}
  image: "{{ .Values.authStripProxy.image.repository }}{{ include "cryostat.imageSeparator" .Values.authStripProxy.image.tag }}{{ .Values.authStripProxy.image.tag }}"
  imagePullPolicy: {{ .Values.authStripProxy.image.pullPolicy }}
  command:
    - nginx
    - -c
    - /etc/nginx-auth-strip/nginx.conf
    - -g
    - daemon off;
  ports:
    - containerPort: 8180
      protocol: TCP
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8180
      scheme: HTTP
  resources:
    {{- toYaml .Values.authStripProxy.resources | nindent 4 }}
  volumeMounts:
    - name: auth-strip-proxy-config
      mountPath: /etc/nginx-auth-strip
      readOnly: true
    - name: user-proxy-secret
      mountPath: /var/run/secrets/cryostat.io/user-proxy
      readOnly: true
{{- end }}

{{/*
The auth strip proxy's nginx.conf. A named template rather than inline in the ConfigMap so that
the Deployment can hash it into a pod annotation: nginx reads this once at startup and never
reloads it, so a change to it has to roll the Pod to take effect.
*/}}
{{- define "cryostat.authStripProxy.config" -}}
worker_processes auto;
error_log stderr notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    access_log /dev/stdout;

    # Cryostat accepts recording uploads of arbitrary size on this path. nginx would
    # otherwise reject anything over its 1m default before Cryostat ever saw it.
    client_max_body_size 0;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    server {
        listen 8180;
        listen [::]:8180;

        location = /healthz {
            return 200;
        }

        location / {
            allow 127.0.0.1;
            allow ::1;
            deny all;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            # Prove to Cryostat that this request came through the authenticating proxy.
            # Mounted from the Secret; contains exactly
            #   proxy_set_header X-Cryostat-User-Proxy-Auth "<secret>";
            # This overwrites any value the client supplied, because proxy_set_header
            # replaces rather than appends.
            include /var/run/secrets/cryostat.io/user-proxy/user-auth.conf;
            # Clear the headers by which a request could otherwise claim to have arrived
            # through the Cryostat Agent gateway. This chart deploys no such gateway, so no
            # request reaching Cryostat through here is ever an agent request. The second is
            # honoured by Cryostat 4.2 and earlier, which core.image.tag may still be pinned
            # to.
            proxy_set_header X-Cryostat-Agent-Auth "";
            proxy_set_header X-Cryostat-Agent-Proxy "";
            # Re-source every forwarded header from this hop's own view of the request, so
            # that a client cannot assert its own identity by sending them itself.
            proxy_set_header X-Forwarded-User $http_x_forwarded_user;
            proxy_set_header X-Forwarded-Access-Token $http_x_forwarded_access_token;
            proxy_set_header X-Forwarded-For $http_x_forwarded_for;
            proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
            proxy_set_header X-Forwarded-Port $http_x_forwarded_port;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Forwarded-Email $http_x_forwarded_email;
            proxy_set_header X-Forwarded-Preferred-Username $http_x_forwarded_preferred_username;
            proxy_set_header X-Forwarded-Groups $http_x_forwarded_groups;
            proxy_pass http://127.0.0.1:8181$request_uri;
        }
    }
}
{{- end }}
