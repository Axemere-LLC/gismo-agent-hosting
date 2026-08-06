# Keyless GitHub Actions -> GCP auth for CI image builds. Federates OIDC
# tokens from github_repo only; no long-lived service-account key is ever
# generated or stored as a GitHub secret.
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions"
  description               = "Federates GitHub Actions OIDC tokens for CI image builds."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  # Restricts which repo's tokens are honored — without this, any repo in
  # any GitHub org could mint a token for this service account.
  attribute_condition = "attribute.repository == \"${var.github_repo}\""

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# CI builds and pushes images only. It gets no run.developer and no access
# to any Tofu state backend — it cannot deploy and cannot touch
# infrastructure. Promoting an image to production is a human `tofu apply`.
resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Gismo agent CI (GitHub Actions)"
}

resource "google_service_account_iam_member" "ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  project    = var.project_id
  location   = var.registry_location
  repository = var.registry_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}
