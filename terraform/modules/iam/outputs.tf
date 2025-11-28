output "dynamic_group_id" {
  description = "Dynamic group OCID for GitHub Actions OIDC"
  value       = var.github_owner != "" ? oci_identity_dynamic_group.github_actions[0].id : null
}

output "dynamic_group_name" {
  description = "Dynamic group name for GitHub Actions OIDC"
  value       = var.github_owner != "" ? oci_identity_dynamic_group.github_actions[0].name : null
}

output "policy_id" {
  description = "Policy OCID granting permissions to GitHub Actions"
  value       = var.github_owner != "" ? oci_identity_policy.github_actions[0].id : null
}

output "github_oidc_setup" {
  description = "Instructions for GitHub repository setup"
  value       = var.github_owner != "" ? <<-EOT

    GitHub OIDC Setup Complete!

    Add these as GitHub Repository Variables (Settings > Secrets and variables > Actions > Variables):

    Variable Name     | Value
    ------------------|-------
    OCI_TENANCY       | ${var.tenancy_id}
    OCI_COMPARTMENT   | ${var.compartment_id}
    OCI_REGION        | (your region, e.g., us-ashburn-1)

    These are NOT secrets - they're public identifiers.
    The OIDC token provides authentication.

  EOT
  : null
}
