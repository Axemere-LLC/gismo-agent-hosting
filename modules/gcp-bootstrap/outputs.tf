output "project_id" {
  value = google_project.agent_host.project_id
}

output "project_number" {
  value = google_project.agent_host.number
}

output "state_bucket_name" {
  value = var.create_state_bucket ? google_storage_bucket.tf_state[0].name : null
}
