variable "grafana_url" {
  description = "Grafana Cloud stack URL"
  type        = string
}

variable "grafana_api_key" {
  description = "Grafana Cloud service account token"
  type        = string
  sensitive   = true
}

variable "loki_datasource_uid" {
  description = "UID of the Loki data source (auto-provisioned by Grafana Cloud)"
  type        = string
  default     = "grafanacloud-logs"
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string
}
