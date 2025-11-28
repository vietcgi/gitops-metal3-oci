#=============================================================================
# IAM Module - GitHub OIDC Federation for GitOps
#
# This module sets up passwordless authentication from GitHub Actions to OCI
# using OpenID Connect (OIDC) Workload Identity Federation.
#
# No static secrets required - GitHub proves its identity cryptographically.
#
# How it works:
# 1. GitHub Actions requests a JWT from GitHub's OIDC provider
# 2. The JWT contains claims: repo, ref, workflow, actor, etc.
# 3. OCI validates the JWT and matches it to this Dynamic Group
# 4. The Dynamic Group has policies granting Terraform permissions
#=============================================================================

locals {
  github_oidc_issuer = "https://token.actions.githubusercontent.com"
}

#-----------------------------------------------------------------------------
# Dynamic Group for GitHub Actions Workload Identity
#
# Matches GitHub OIDC tokens from specific repository.
# Only workflows from YOUR repo can assume this identity.
#-----------------------------------------------------------------------------

resource "oci_identity_dynamic_group" "github_actions" {
  count = var.github_owner != "" ? 1 : 0

  compartment_id = var.tenancy_id
  name           = "${var.project_name}-github-actions"
  description    = "GitHub Actions OIDC from ${var.github_owner}/${var.github_repo}"

  # Match GitHub OIDC tokens with specific claims
  # Only tokens from your repo on main branch get access
  matching_rule = "ALL {resource.type='github-actions', resource.repository='${var.github_owner}/${var.github_repo}', resource.ref='refs/heads/main'}"

  freeform_tags = var.tags
}

#-----------------------------------------------------------------------------
# IAM Policies for GitOps Workflows
#
# These policies grant the GitHub Actions dynamic group permissions
# to manage infrastructure via Terraform.
#-----------------------------------------------------------------------------

resource "oci_identity_policy" "github_actions" {
  count = var.github_owner != "" ? 1 : 0

  compartment_id = var.tenancy_id
  name           = "${var.project_name}-github-actions-policy"
  description    = "Policies for GitHub Actions GitOps workflows"

  statements = [
    # Allow managing compute instances
    "Allow dynamic-group ${oci_identity_dynamic_group.github_actions[0].name} to manage instance-family in compartment id ${var.compartment_id}",

    # Allow managing VCN resources
    "Allow dynamic-group ${oci_identity_dynamic_group.github_actions[0].name} to manage virtual-network-family in compartment id ${var.compartment_id}",

    # Allow managing object storage (for Terraform state)
    "Allow dynamic-group ${oci_identity_dynamic_group.github_actions[0].name} to manage object-family in compartment id ${var.compartment_id}",

    # Allow reading compartment info
    "Allow dynamic-group ${oci_identity_dynamic_group.github_actions[0].name} to read compartments in compartment id ${var.compartment_id}",

    # Allow managing load balancers
    "Allow dynamic-group ${oci_identity_dynamic_group.github_actions[0].name} to manage load-balancers in compartment id ${var.compartment_id}",

    # Allow reading tenancy info (for availability domains)
    "Allow dynamic-group ${oci_identity_dynamic_group.github_actions[0].name} to read all-resources in tenancy",
  ]

  freeform_tags = var.tags
}
