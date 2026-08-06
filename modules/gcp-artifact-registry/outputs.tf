output "repository_id" {
  value = google_artifact_registry_repository.agents.repository_id
}

output "repository_url" {
  description = "Push/pull prefix for this repo, e.g. \"us-central1-docker.pkg.dev/PROJECT/REPO\"."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.agents.repository_id}"
}
