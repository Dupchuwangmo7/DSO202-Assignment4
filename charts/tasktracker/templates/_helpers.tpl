{{/*
=============================================================================
File       : charts/tasktracker/templates/_helpers.tpl
Assignment : DSO202 Assignment 4
Descriptor : Unit III 3.2 - Helm named templates
Purpose    : Named templates shared by every file in templates/.
             Files beginning with _ never produce Kubernetes objects.
============================================================================= */}}

{{- define "task-tracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Base name for objects. Truncated to 63 chars (the Kubernetes DNS label limit).
If the release name already contains the chart name, it is used alone.
*/}}
{{- define "task-tracker.fullname" -}}
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

{{- define "task-tracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Environment name. `required` stops rendering with this message when unset.
*/}}
{{- define "task-tracker.environment" -}}
{{- required "environment must be set (dev or prod)" .Values.environment }}
{{- end }}

{{/*
Selector labels: the SMALL, STABLE set. Deployment and StatefulSet selectors
are immutable after creation, so nothing that changes between versions may
appear here. `tier` is supplied by the caller.
*/}}
{{- define "task-tracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "task-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full label set: adds labels that DO change between versions.
*/}}
{{- define "task-tracker.labels" -}}
helm.sh/chart: {{ include "task-tracker.chart" . }}
{{ include "task-tracker.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
dso202/environment: {{ include "task-tracker.environment" . | quote }}
{{- end }}
