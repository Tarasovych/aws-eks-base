locals {
  grafana_password         = random_string.grafana_password.result
  grafana_domain_name      = "grafana-${var.domain_suffix}"
  prometheus_domain_name   = "prometheus-${var.domain_suffix}"
  alertmanager_domain_name = "alertmanager-${var.domain_suffix}"

  kube_prometheus_stack_template = templatefile("${path.module}/templates/prometheus-values.tmpl",
    {
      prometheus_domain_name           = local.prometheus_domain_name
      alertmanager_domain_name         = local.alertmanager_domain_name
      ip_whitelist                     = var.ip_whitelist
      default_region                   = var.region
      grafana_domain_name              = local.grafana_domain_name
      grafana_password                 = local.grafana_password
      role_arn                         = module.aws_iam_grafana.role_arn
      grafana_gitlab_oauth_enabled     = var.grafana_gitlab_oauth_enabled
      grafana_github_oauth_enabled     = var.grafana_github_oauth_enabled
      grafana_oauth_client_id          = var.grafana_oauth_client_id
      grafana_oauth_client_secret      = var.grafana_oauth_client_secret
      grafana_oauth_gitlab_group       = var.grafana_oauth_gitlab_group
      grafana_oauth_github_teams_ids   = var.grafana_oauth_github_teams_ids
      grafana_oauth_github_allowed_org = var.grafana_oauth_github_allowed_org

      alertmanager_slack_url     = var.alertmanager_slack_url
      alertmanager_slack_channel = var.alertmanager_slack_channel
  })
}
