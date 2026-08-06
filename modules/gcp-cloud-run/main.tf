# One dedicated service account per agent, rather than the project's default
# compute SA, so an agent's runtime identity holds exactly the grants this
# module gives it (none, beyond what running the container requires) and
# nothing a consumer's other workloads happen to have accumulated.
resource "google_service_account" "agent" {
  project      = var.project_id
  account_id   = var.agent_name
  display_name = "Gismo agent: ${var.agent_name}"
}

locals {
  # Unifies plain and secret-sourced env vars into one list so a single
  # dynamic "env" block below can emit both — each entry sets exactly one
  # of value/secret_id, matching gismo-platform's infra/modules/run pattern.
  env_entries = concat(
    [for name, value in var.env : { name = name, value = value, secret_id = null }],
    [for name, secret_id in var.secret_env : { name = name, value = null, secret_id = secret_id }],
  )
}

resource "google_cloud_run_v2_service" "agent" {
  project  = var.project_id
  name     = var.agent_name
  location = var.region

  # ALL, not INTERNAL_ONLY: a Gismo referee calls this endpoint from
  # outside the project. There is no load balancer in front of this module
  # (see docs/module-contract.md) for that traffic to route through.
  ingress = "INGRESS_TRAFFIC_ALL"

  labels = merge({ "gismo-agent" = var.agent_name }, var.labels)

  template {
    service_account = google_service_account.agent.email
    timeout         = "${var.request_timeout_seconds}s"

    max_instance_request_concurrency = var.concurrency

    scaling {
      # Omitted (null) rather than 0 when min_instances is 0: Cloud Run
      # never echoes an explicit min_instance_count=0 back on read, which
      # would otherwise show as a perpetual diff on every subsequent plan.
      min_instance_count = var.min_instances > 0 ? var.min_instances : null
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      dynamic "env" {
        for_each = local.env_entries
        content {
          name  = env.value.name
          value = env.value.value

          dynamic "value_source" {
            for_each = env.value.secret_id != null ? [env.value.secret_id] : []
            content {
              secret_key_ref {
                secret  = value_source.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  # The v2 API always echoes a legacy top-level `scaling` block mirroring
  # template.scaling, which the provider re-diffs as removed on every plan
  # even though this config never sets it directly.
  lifecycle {
    ignore_changes = [scaling]
  }
}

# Public and unauthenticated by default: see docs/module-contract.md's
# "What the core module deliberately does not do" for why a Gismo agent's
# own bearer-key auth cannot coexist with provider-native IAM auth on the
# same Authorization header. Skipped entirely when public_invoker = false,
# leaving the service reachable only to identities the consumer grants
# roles/run.invoker to outside this module.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.public_invoker ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.agent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
