variable "project_id" {
  description = "GCP project ID to deploy the agent into."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run service."
  type        = string
  default     = "us-central1"
}

variable "agent_name" {
  description = "Names the Cloud Run service and its runtime service account. See docs/module-contract.md#naming-rules."
  type        = string

  # Tighter than Cloud Run's own 63-char service-name limit: the derived
  # service-account account_id caps at 30 chars and requires 6+, so that's
  # the binding constraint. Validated once here rather than surfacing GCP's
  # less legible SA-creation error at apply time.
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.agent_name))
    error_message = "agent_name must be 6-30 chars, lowercase alphanumeric and hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "image" {
  description = "Digest-pinned container image, e.g. \"us-central1-docker.pkg.dev/proj/repo/agent@sha256:<64 hex>\". Mutable tags (:latest, a branch name) are rejected."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must be pinned to a digest (...@sha256:<64 hex chars>), not a mutable tag. See docs/module-contract.md#what-the-core-module-deliberately-does-not-do."
  }
}

variable "cpu" {
  description = "vCPU allocation. Cloud Run rejects values below 1 under always-allocated CPU (the mode this module always uses)."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation, e.g. \"512Mi\" or \"1Gi\"."
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Idle instance floor. 0 is true scale-to-zero (~$0 when idle) — see docs/cost.md."
  type        = number
  default     = 0

  validation {
    condition     = var.min_instances >= 0
    error_message = "min_instances must be >= 0."
  }
}

variable "max_instances" {
  description = "Concurrency ceiling. A correctness setting, not just a cost control — see docs/module-contract.md's warning before raising this above 1 for a gismo-agent-go-based agent."
  type        = number
  default     = 1

  validation {
    condition     = var.max_instances >= 1
    error_message = "max_instances must be >= 1."
  }
}

variable "request_timeout_seconds" {
  description = "Per-request timeout at the platform edge."
  type        = number
  default     = 300
}

variable "concurrency" {
  description = "Max in-flight requests per instance."
  type        = number
  default     = 80
}

variable "env" {
  description = "Plain (non-secret) environment variables passed to the container."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Environment variables sourced from Secret Manager instead of a literal value. Key is the env var name; value is the Secret Manager secret ID (not the full resource path). Always the \"latest\" version."
  type        = map(string)
  default     = {}
}

variable "public_invoker" {
  description = "Whether the endpoint accepts unauthenticated requests. Default true because a Gismo referee's bearer-key auth and provider IAM auth cannot coexist on the same Authorization header — see docs/module-contract.md."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Resource labels, merged with this module's own \"gismo-agent\" label."
  type        = map(string)
  default     = {}
}
