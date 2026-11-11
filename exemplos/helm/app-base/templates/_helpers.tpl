{{/*
Nome da aplicação. É o releaseName que cada overlay passa ao inflar o chart.
*/}}
{{- define "app-base.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Rótulos de seleção. Pequenos e estáveis: mudar seletor de Deployment exige
recriar o objeto, então nada que varie por versão entra aqui.
*/}}
{{- define "app-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app-base.fullname" . }}
{{- end -}}

{{/*
Rótulos completos. sefaz.io/time e sefaz.io/ambiente são lidos pelo coletor
OpenTelemetry (carimbo de log e trace) e pelo PodMonitor (rótulo da métrica).
*/}}
{{- define "app-base.labels" -}}
{{ include "app-base.selectorLabels" . }}
app.kubernetes.io/part-of: {{ required "time é obrigatório" .Values.time }}
app.kubernetes.io/managed-by: argocd
sefaz.io/time: {{ .Values.time }}
sefaz.io/ambiente: {{ .Values.ambiente }}
sefaz.io/tier: {{ .Values.tier | quote }}
{{- end -}}
