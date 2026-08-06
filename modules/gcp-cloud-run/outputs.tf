output "endpoint_url" {
  description = "The service's https:// URL — paste this into mcp_endpoint_url when registering the agent version."
  value       = google_cloud_run_v2_service.agent.uri
}

output "service_name" {
  description = "Cloud Run service name, for lookups outside this module (logs, dashboards)."
  value       = google_cloud_run_v2_service.agent.name
}

output "service_account_email" {
  description = "The agent's runtime identity. Grant it further permissions outside this module only if your Strategy needs them."
  value       = google_service_account.agent.email
}
