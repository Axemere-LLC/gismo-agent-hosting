variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "github_repo" {
  description = "GitHub repo allowed to federate, as \"owner/repo\". Only tokens minted for this exact repo can assume the CI service account — no other repo, in any org, can."
  type        = string
}

variable "registry_location" {
  description = "Artifact Registry location the CI service account should be allowed to push to."
  type        = string
}

variable "registry_repository_id" {
  description = "Artifact Registry repository ID the CI service account should be allowed to push to (e.g. modules/gcp-artifact-registry's output)."
  type        = string
}

variable "service_account_id" {
  description = "Account ID for the CI service account (6-30 chars)."
  type        = string
  default     = "gismo-agent-ci"
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "github-actions"
}
