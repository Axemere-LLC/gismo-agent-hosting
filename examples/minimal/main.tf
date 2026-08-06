# The smallest possible consumer of this repo: an existing GCP project, an
# already-built and already-pushed image, one module call.
module "agent" {
  # A real consumer pins a released version instead of a local path:
  #   source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-cloud-run?ref=v0.1.0"
  source = "../../modules/gcp-cloud-run"

  project_id = var.project_id
  region     = var.region
  agent_name = var.agent_name
  image      = var.image

  secret_env = var.outbound_key_secret_id == null ? {} : {
    MCP_OUTBOUND_KEY = var.outbound_key_secret_id
  }
}
