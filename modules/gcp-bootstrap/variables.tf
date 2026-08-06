variable "project_id" {
  description = "GCP project ID to create (globally unique, 6-30 chars)."
  type        = string
}

variable "project_name" {
  description = "Human-readable project display name. Defaults to project_id."
  type        = string
  default     = null
}

variable "org_id" {
  description = "GCP organization ID to create the project under. Mutually exclusive with folder_id; leave both null to create the project without a parent resource (requires the caller to hold project-creation rights at that scope)."
  type        = string
  default     = null
}

variable "folder_id" {
  description = "GCP folder ID to create the project under. Mutually exclusive with org_id."
  type        = string
  default     = null
}

variable "billing_account_id" {
  description = "Billing account to link. Required for any billable API (Cloud Run, Artifact Registry) to function, even though this module's own resources stay within GCP's always-free tier at idle — see docs/cost.md."
  type        = string
}

variable "region" {
  description = "Default region, used only for the optional Tofu state bucket."
  type        = string
  default     = "us-central1"
}

variable "apis" {
  description = "APIs to enable. The defaults cover modules/gcp-cloud-run, modules/gcp-artifact-registry, and modules/gcp-cicd; trim or extend for what you actually use."
  type        = list(string)
  default = [
    "run.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
}

variable "create_state_bucket" {
  description = "Whether to create a GCS bucket for this project's own Tofu/OpenTofu state. Off by default — many consumers already have a state backend and don't want this module opinionated about it."
  type        = bool
  default     = false
}
