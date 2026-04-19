output "dashboard_urls" {
  description = "URLs to the Grafana dashboards"
  value = {
    app_overview = "${var.grafana_url}/d/hoopsmgr-app-overview"
    nginx        = "${var.grafana_url}/d/hoopsmgr-nginx"
  }
}

output "folder_uid" {
  description = "UID of the HoopsMgr dashboard folder"
  value       = grafana_folder.hoopsmgr.uid
}
