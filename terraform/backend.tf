#=============================================================================
# Terraform Backend Configuration
#
# By default, Terraform uses local state. For team collaboration and CI/CD,
# configure remote state using OCI Object Storage.
#
# To enable remote state:
# 1. First run: terraform apply (creates the bucket)
# 2. Uncomment the backend block below
# 3. Run: terraform init -migrate-state
#=============================================================================

# Uncomment this block after the first run to migrate state to OCI Object Storage
#
# terraform {
#   backend "s3" {
#     # OCI Object Storage uses S3-compatible API
#     bucket   = "metal3-oci-state"
#     key      = "terraform.tfstate"
#     region   = "us-ashburn-1"  # Change to your region
#
#     # OCI Object Storage S3 endpoint
#     # Format: https://<namespace>.compat.objectstorage.<region>.oraclecloud.com
#     endpoint = "https://NAMESPACE.compat.objectstorage.REGION.oraclecloud.com"
#
#     # Disable S3-specific features not supported by OCI
#     skip_region_validation      = true
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     force_path_style            = true
#
#     # Use OCI credentials (set via environment variables or ~/.oci/config)
#     # AWS_ACCESS_KEY_ID = OCI Customer Secret Key (Access Key)
#     # AWS_SECRET_ACCESS_KEY = OCI Customer Secret Key (Secret Key)
#   }
# }

#=============================================================================
# Alternative: Use Terraform Cloud (Free for small teams)
#=============================================================================

# terraform {
#   cloud {
#     organization = "your-org"
#
#     workspaces {
#       name = "metal3-oci"
#     }
#   }
# }
