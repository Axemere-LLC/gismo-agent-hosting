variable "project_id" {
  description = "An existing GCP project with billing and the Cloud Run API already enabled."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "agent_name" {
  type    = string
  default = "gismo-agent-minimal"
}

variable "image" {
  description = "Digest-pinned image already pushed somewhere this project can pull from."
  type        = string
}

variable "outbound_key_secret_id" {
  description = "Secret Manager secret ID holding the bearer key your agent checks incoming requests against. Optional — omit to run unauthenticated (fine for a Training Grounds agent with no data to protect)."
  type        = string
  default     = null
}
