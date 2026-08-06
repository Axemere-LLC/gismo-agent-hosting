resource "google_artifact_registry_repository" "agents" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = var.description

  cleanup_policies {
    id     = "keep-last-${var.keep_count}"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged-after-${var.delete_untagged_after_days}d"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.delete_untagged_after_days * 86400}s"
    }
  }
}
