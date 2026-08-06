# A Google Workspace-backed org typically enforces
# constraints/iam.allowedPolicyMemberDomains (Domain Restricted Sharing) by
# default, which blocks allUsers/allAuthenticatedUsers IAM bindings —
# required by modules/gcp-cloud-run's public_invoker = true default (its
# out-of-the-box setting) whenever this project sits under such an org.
# Projects with no org, or an org that doesn't enforce this constraint,
# don't need this module at all.
resource "google_org_policy_policy" "allow_public_iam_members" {
  name   = "projects/${var.project_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      allow_all = "TRUE"
    }
  }
}
