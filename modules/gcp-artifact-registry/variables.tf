variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the Artifact Registry repository."
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Repository name."
  type        = string
  default     = "gismo-agents"
}

variable "description" {
  description = "Repository description."
  type        = string
  default     = "Gismo agent container images."
}

variable "keep_count" {
  description = "How many most-recent tagged versions per image name to always retain, regardless of age."
  type        = number
  default     = 5
}

variable "delete_untagged_after_days" {
  description = "Delete untagged image versions older than this many days. A digest still referenced by a deployed Cloud Run revision is always tagged (see docs/building-your-image.md), so this never deletes an image a running service depends on."
  type        = number
  default     = 30
}
