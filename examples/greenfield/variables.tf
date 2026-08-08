variable "project_id" {
  description = "New GCP project ID to create (globally unique, 6-30 chars). Chosen by you up front, not generated — so the provider block above can target it before it exists."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "billing_account_id" {
  type = string
}

variable "org_id" {
  type    = string
  default = null
}

variable "folder_id" {
  type    = string
  default = null
}

variable "github_repo" {
  description = "\"owner/repo\" allowed to push images via modules/gcp-cicd."
  type        = string
}

variable "needs_public_iam_exception" {
  description = "Set true only if applying without it fails on the allUsers grant (an org enforcing Domain Restricted Sharing) — see modules/gcp-org-policy. Most consumers leave this false."
  type        = bool
  default     = false
}

variable "agent_name" {
  type    = string
  default = "gismo-agent"
}

variable "deploy_agent" {
  description = "Leave false on the first apply — there's no image to deploy yet. Build and push an image through the registry this example creates (via the CI it also creates, or a local docker push), then re-apply with this set true and image populated. See this example's README for the full two-stage flow."
  type        = bool
  default     = false
}

variable "image" {
  description = "Digest-pinned image, required once deploy_agent = true."
  type        = string
  default     = null
}

variable "outbound_key_secret_id" {
  description = "Secret Manager secret ID holding the bearer key your agent checks incoming requests against. Optional — omit to run unauthenticated (fine for a Training Grounds agent with no data to protect)."
  type        = string
  default     = null
}
