{{/*
Expand the name of the chart.
*/}}
{{- define "keeper-injector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "keeper-injector.fullname" -}}
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
{{- define "keeper-injector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "keeper-injector.labels" -}}
helm.sh/chart: {{ include "keeper-injector.chart" . }}
{{ include "keeper-injector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "keeper-injector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keeper-injector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "keeper-injector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "keeper-injector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Webhook image reference
*/}}
{{- define "keeper-injector.webhookImage" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Sidecar image reference
*/}}
{{- define "keeper-injector.sidecarImage" -}}
{{- $tag := default .Chart.AppVersion .Values.sidecar.tag }}
{{- printf "%s:%s" .Values.sidecar.repository $tag }}
{{- end }}

{{/*
Certificate secret name
*/}}
{{- define "keeper-injector.certSecretName" -}}
{{- printf "%s-tls" (include "keeper-injector.fullname" .) }}
{{- end }}

{{/*
Webhook service name
*/}}
{{- define "keeper-injector.webhookServiceName" -}}
{{- printf "%s-webhook" (include "keeper-injector.fullname" .) }}
{{- end }}
