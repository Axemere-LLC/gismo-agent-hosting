# Starting from nothing: no GCP project, no registry, no CI. Chains every
# optional module together. Two-stage by necessity — see this example's
# README — the second stage (module.agent) only activates once an image
# actually exists to deploy, gated by var.deploy_agent.
module "bootstrap" {
  source = "../../modules/gcp-bootstrap"

  project_id         = var.project_id
  billing_account_id = var.billing_account_id
  org_id             = var.org_id
  folder_id          = var.folder_id
  region             = var.region
}

module "registry" {
  source     = "../../modules/gcp-artifact-registry"
  depends_on = [module.bootstrap]

  project_id = var.project_id
  region     = var.region
}

module "cicd" {
  source     = "../../modules/gcp-cicd"
  depends_on = [module.bootstrap]

  project_id             = var.project_id
  github_repo            = var.github_repo
  registry_location      = var.region
  registry_repository_id = module.registry.repository_id
}

module "org_policy_exception" {
  count      = var.needs_public_iam_exception ? 1 : 0
  source     = "../../modules/gcp-org-policy"
  depends_on = [module.bootstrap]

  project_id = var.project_id
}

module "agent" {
  count      = var.deploy_agent ? 1 : 0
  source     = "../../modules/gcp-cloud-run"
  depends_on = [module.bootstrap, module.org_policy_exception]

  project_id = var.project_id
  region     = var.region
  agent_name = var.agent_name
  image      = var.image

  secret_env = var.outbound_key_secret_id == null ? {} : {
    MCP_OUTBOUND_KEY = var.outbound_key_secret_id
  }
}
