output "project_id" {
  value = module.bootstrap.project_id
}

output "registry_url" {
  value = module.registry.repository_url
}

output "ci_service_account_email" {
  value = module.cicd.service_account_email
}

output "ci_workload_identity_provider" {
  value = module.cicd.workload_identity_provider
}

output "endpoint_url" {
  value = try(module.agent[0].endpoint_url, null)
}
