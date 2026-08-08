terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0, < 7.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # modules/gcp-org-policy's google_org_policy_policy resource calls the
  # Org Policy v2 API, which (unlike Cloud Run/Artifact Registry/IAM above)
  # refuses to infer a quota project from ADC and errors with "SERVICE_DISABLED"
  # against a Google-internal placeholder project otherwise. Only exercised
  # when needs_public_iam_exception = true.
  user_project_override = true
  billing_project       = var.project_id
}
