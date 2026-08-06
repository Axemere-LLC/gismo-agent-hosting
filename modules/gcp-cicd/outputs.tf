output "service_account_email" {
  value = google_service_account.ci.email
}

output "workload_identity_provider" {
  description = "Full provider resource name — pass this as workload_identity_provider to google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}
