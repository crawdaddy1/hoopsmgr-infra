# ─── Folders ────────────────────────────────────────────────────
resource "grafana_folder" "hoopsmgr" {
  title = "HoopsMgr"
}

# ─── Contact Point (email) ─────────────────────────────────────
resource "grafana_contact_point" "email" {
  name = "hoopsmgr-email"

  email {
    addresses = [var.notification_email]
  }
}

# ─── Notification Policy ───────────────────────────────────────
resource "grafana_notification_policy" "default" {
  contact_point = grafana_contact_point.email.name
  group_by      = ["alertname"]

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"
}

# ─── Dashboard: Application Overview ──────────────────────────
resource "grafana_dashboard" "app_overview" {
  folder    = grafana_folder.hoopsmgr.id
  overwrite = true

  config_json = jsonencode({
    title       = "HoopsMgr - Application Overview"
    uid         = "hoopsmgr-app-overview"
    tags        = ["hoopsmgr", "production"]
    timezone    = "browser"
    refresh     = "30s"
    time = {
      from = "now-1h"
      to   = "now"
    }
    panels = [
      # ── Row: Request Traffic ──
      {
        id       = 1
        type     = "row"
        title    = "Request Traffic"
        gridPos  = { h = 1, w = 24, x = 0, y = 0 }
      },
      {
        id    = 2
        type  = "timeseries"
        title = "HTTP Requests (nginx)"
        gridPos = { h = 8, w = 12, x = 0, y = 1 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "sum(rate({service=\"react\", env=\"production\"} |~ \"(GET|POST|PUT|PATCH|DELETE)\" [5m])) by ()"
            legendFormat = "requests/s"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            custom = { fillOpacity = 20 }
          }
        }
      },
      {
        id    = 3
        type  = "timeseries"
        title = "HTTP Errors (4xx/5xx)"
        gridPos = { h = 8, w = 12, x = 12, y = 1 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "sum(rate({service=\"react\", env=\"production\"} |~ \"\\\" (4\\\\d{2}|5\\\\d{2}) \" [5m])) by ()"
            legendFormat = "errors/s"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            color = { mode = "fixed", fixedColor = "red" }
            custom = { fillOpacity = 20 }
          }
        }
      },

      # ── Row: Django API ──
      {
        id       = 4
        type     = "row"
        title    = "Django API"
        gridPos  = { h = 1, w = 24, x = 0, y = 9 }
      },
      {
        id    = 5
        type  = "logs"
        title = "Django Logs"
        gridPos = { h = 10, w = 24, x = 0, y = 10 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "{service=\"web\", env=\"production\"}"
          }
        ]
        options = {
          showTime       = true
          showLabels     = true
          wrapLogMessage = true
          sortOrder      = "Descending"
          enableLogDetails = true
        }
      },

      # ── Row: User Activity ──
      {
        id       = 6
        type     = "row"
        title    = "User Activity"
        gridPos  = { h = 1, w = 24, x = 0, y = 20 }
      },
      {
        id    = 7
        type  = "stat"
        title = "Logins (last 1h)"
        gridPos = { h = 4, w = 6, x = 0, y = 21 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "count_over_time({service=\"web\", env=\"production\"} |~ \"login_success|token_obtain\" [1h])"
          }
        ]
        fieldConfig = {
          defaults = {
            color = { mode = "fixed", fixedColor = "green" }
          }
        }
      },
      {
        id    = 8
        type  = "stat"
        title = "Registrations (last 1h)"
        gridPos = { h = 4, w = 6, x = 6, y = 21 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "count_over_time({service=\"web\", env=\"production\"} |~ \"register|registration\" [1h])"
          }
        ]
        fieldConfig = {
          defaults = {
            color = { mode = "fixed", fixedColor = "blue" }
          }
        }
      },
      {
        id    = 9
        type  = "stat"
        title = "Failed Logins (last 1h)"
        gridPos = { h = 4, w = 6, x = 12, y = 21 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "count_over_time({service=\"web\", env=\"production\"} |~ \"login_failed|401\" [1h])"
          }
        ]
        fieldConfig = {
          defaults = {
            color = { mode = "fixed", fixedColor = "red" }
          }
        }
      },
      {
        id    = 10
        type  = "stat"
        title = "Team Creates (last 1h)"
        gridPos = { h = 4, w = 6, x = 18, y = 21 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "count_over_time({service=\"web\", env=\"production\"} |~ \"team.*created|POST.*teams\" [1h])"
          }
        ]
        fieldConfig = {
          defaults = {
            color = { mode = "fixed", fixedColor = "purple" }
          }
        }
      },

      # ── Row: All Container Logs ──
      {
        id       = 11
        type     = "row"
        title    = "All Container Logs"
        gridPos  = { h = 1, w = 24, x = 0, y = 25 }
      },
      {
        id    = 12
        type  = "logs"
        title = "All Logs (by service)"
        gridPos = { h = 12, w = 24, x = 0, y = 26 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "{env=\"production\"}"
          }
        ]
        options = {
          showTime       = true
          showLabels     = true
          wrapLogMessage = true
          sortOrder      = "Descending"
          enableLogDetails = true
        }
      }
    ]
  })
}

# ─── Dashboard: Nginx Access ──────────────────────────────────
resource "grafana_dashboard" "nginx" {
  folder    = grafana_folder.hoopsmgr.id
  overwrite = true

  config_json = jsonencode({
    title       = "HoopsMgr - Nginx Access"
    uid         = "hoopsmgr-nginx"
    tags        = ["hoopsmgr", "nginx"]
    timezone    = "browser"
    refresh     = "30s"
    time = {
      from = "now-1h"
      to   = "now"
    }
    panels = [
      {
        id    = 1
        type  = "timeseries"
        title = "Requests by Status Code"
        gridPos = { h = 8, w = 24, x = 0, y = 0 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "2xx"
            expr  = "sum(rate({service=\"react\", env=\"production\"} |~ \"\\\" 2\\\\d{2} \" [5m]))"
            legendFormat = "2xx"
          },
          {
            refId = "3xx"
            expr  = "sum(rate({service=\"react\", env=\"production\"} |~ \"\\\" 3\\\\d{2} \" [5m]))"
            legendFormat = "3xx"
          },
          {
            refId = "4xx"
            expr  = "sum(rate({service=\"react\", env=\"production\"} |~ \"\\\" 4\\\\d{2} \" [5m]))"
            legendFormat = "4xx"
          },
          {
            refId = "5xx"
            expr  = "sum(rate({service=\"react\", env=\"production\"} |~ \"\\\" 5\\\\d{2} \" [5m]))"
            legendFormat = "5xx"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            custom = { fillOpacity = 20 }
          }
          overrides = [
            { matcher = { id = "byName", options = "2xx" }, properties = [{ id = "color", value = { fixedColor = "green", mode = "fixed" } }] },
            { matcher = { id = "byName", options = "3xx" }, properties = [{ id = "color", value = { fixedColor = "blue", mode = "fixed" } }] },
            { matcher = { id = "byName", options = "4xx" }, properties = [{ id = "color", value = { fixedColor = "orange", mode = "fixed" } }] },
            { matcher = { id = "byName", options = "5xx" }, properties = [{ id = "color", value = { fixedColor = "red", mode = "fixed" } }] }
          ]
        }
      },
      {
        id    = 2
        type  = "table"
        title = "Top Requested Paths"
        gridPos = { h = 8, w = 12, x = 0, y = 8 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "topk(20, sum by (path) (count_over_time({service=\"react\", env=\"production\"} | pattern `<ip> - - [<_>] \"<method> <path> <_>\" <status> <_> <_> <_> <_>` [1h])))"
          }
        ]
      },
      {
        id    = 3
        type  = "logs"
        title = "Nginx Access Log"
        gridPos = { h = 10, w = 24, x = 0, y = 16 }
        datasource = { uid = var.loki_datasource_uid, type = "loki" }
        targets = [
          {
            refId = "A"
            expr  = "{service=\"react\", env=\"production\"}"
          }
        ]
        options = {
          showTime       = true
          wrapLogMessage = true
          sortOrder      = "Descending"
          enableLogDetails = true
        }
      }
    ]
  })
}

# ─── Alert Rules ───────────────────────────────────────────────
resource "grafana_rule_group" "hoopsmgr_alerts" {
  name             = "HoopsMgr Alerts"
  folder_uid       = grafana_folder.hoopsmgr.uid
  interval_seconds = 300

  # Alert: High error rate (>10 5xx errors in 5 min)
  rule {
    name           = "High 5xx Error Rate"
    condition      = "threshold"
    no_data_state  = "OK"
    exec_err_state = "OK"

    data {
      ref_id         = "errors"
      datasource_uid = var.loki_datasource_uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        expr     = "count_over_time({service=\"react\", env=\"production\"} |~ \"\\\" 5\\\\d{2} \" [5m])"
        refId    = "errors"
      })
    }

    data {
      ref_id         = "threshold"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "classic_conditions"
        refId      = "threshold"
        conditions = [{
          type = "query"
          evaluator = {
            type   = "gt"
            params = [10]
          }
          operator = { type = "and" }
          query    = { params = ["errors"] }
          reducer  = { type = "last", params = [] }
        }]
      })
    }

    labels = {
      severity = "critical"
    }

    annotations = {
      summary     = "High 5xx error rate on HoopsMgr"
      description = "More than 10 server errors in the last 5 minutes."
    }
  }

  # Alert: Django container down (no logs in 10 min)
  rule {
    name           = "Django Container Down"
    condition      = "threshold"
    for            = "5m"
    no_data_state  = "Alerting"
    exec_err_state = "OK"

    data {
      ref_id         = "logs"
      datasource_uid = var.loki_datasource_uid

      relative_time_range {
        from = 600
        to   = 0
      }

      model = jsonencode({
        # Count heartbeat lines emitted by the /healthz endpoint. Docker's
        # HEALTHCHECK hits /healthz every 30s, so we expect ~20 lines/10min.
        # A quiet traffic period no longer produces a false positive.
        expr  = "count_over_time({service=\"web\", env=\"production\"} |= \"healthz_heartbeat\" [10m])"
        refId = "logs"
      })
    }

    data {
      ref_id         = "threshold"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "classic_conditions"
        refId      = "threshold"
        conditions = [{
          type = "query"
          evaluator = {
            type   = "lt"
            params = [1]
          }
          operator = { type = "and" }
          query    = { params = ["logs"] }
          reducer  = { type = "last", params = [] }
        }]
      })
    }

    labels = {
      severity = "critical"
    }

    annotations = {
      summary     = "Django container appears down"
      description = "No logs from the web (Django) container in the last 10 minutes."
    }
  }

  # Alert: Nginx container down
  rule {
    name           = "Nginx Container Down"
    condition      = "threshold"
    for            = "5m"
    no_data_state  = "Alerting"
    exec_err_state = "OK"

    data {
      ref_id         = "logs"
      datasource_uid = var.loki_datasource_uid

      relative_time_range {
        from = 600
        to   = 0
      }

      model = jsonencode({
        expr  = "count_over_time({service=\"react\", env=\"production\"} [10m])"
        refId = "logs"
      })
    }

    data {
      ref_id         = "threshold"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "classic_conditions"
        refId      = "threshold"
        conditions = [{
          type = "query"
          evaluator = {
            type   = "lt"
            params = [1]
          }
          operator = { type = "and" }
          query    = { params = ["logs"] }
          reducer  = { type = "last", params = [] }
        }]
      })
    }

    labels = {
      severity = "critical"
    }

    annotations = {
      summary     = "Nginx container appears down"
      description = "No logs from the react (Nginx) container in the last 10 minutes."
    }
  }
}
