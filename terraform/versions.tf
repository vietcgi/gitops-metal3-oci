terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }

  # OCI Object Storage backend (native)
  backend "oci" {
    bucket    = "metal3-oci-state"
    namespace = "iddc1lpdwqeb"
    region    = "us-ashburn-1"
    key       = "terraform.tfstate"
  }
}

provider "oci" {
  region       = var.region
  tenancy_ocid = var.tenancy_ocid

  # API Key auth (CI/CD) - used when private_key is provided
  user_ocid   = var.private_key != "" ? var.user_ocid : null
  fingerprint = var.private_key != "" ? var.fingerprint : null
  private_key = var.private_key != "" ? var.private_key : null

  # CLI Session Token auth (local dev) - used when no private_key
  config_file_profile = var.private_key == "" ? var.oci_config_profile : null
  auth                = var.private_key == "" ? "SecurityToken" : "ApiKey"
}
