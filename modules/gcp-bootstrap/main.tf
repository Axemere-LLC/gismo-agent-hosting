# Creates the project itself, so this module has to run with credentials
# scoped above the project it's creating (an org/folder admin, or a user
# with project-creation rights) — everything else in this repo runs scoped
# to a single already-existing project.
resource "google_project" "agent_host" {
  name            = coalesce(var.project_name, var.project_id)
  project_id      = var.project_id
  org_id          = var.org_id
  folder_id       = var.folder_id
  billing_account = var.billing_account_id
}

resource "google_project_service" "apis" {
  for_each = toset(var.apis)

  project            = google_project.agent_host.project_id
  service            = each.value
  disable_on_destroy = false
}

# Optional: this consumer's own Tofu/OpenTofu state bucket for the project
# being bootstrapped. Versioned so a bad apply's prior state is recoverable.
resource "google_storage_bucket" "tf_state" {
  count = var.create_state_bucket ? 1 : 0

  project                     = google_project.agent_host.project_id
  name                        = "${var.project_id}-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.apis]
}
