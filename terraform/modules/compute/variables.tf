variable "compartment_id" {
  description = "Compartment OCID"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "subnet_id" {
  description = "Subnet OCID for the instance"
  type        = string
}

variable "nsg_ids" {
  description = "Network Security Group OCIDs"
  type        = list(string)
  default     = []
}

variable "shape" {
  description = "Instance shape (Always Free only)"
  type        = string

  validation {
    condition = contains([
      "VM.Standard.E2.1.Micro",
      "VM.Standard.A1.Flex"
    ], var.shape)
    error_message = "Only Always Free shapes allowed"
  }
}

variable "ocpus" {
  description = "OCPUs for A1.Flex (ignored for E2.1.Micro)"
  type        = number
  default     = null
}

variable "memory_gb" {
  description = "Memory in GB for A1.Flex (ignored for E2.1.Micro)"
  type        = number
  default     = null
}

variable "image_id" {
  description = "Image OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB"
  type        = number
  default     = 50
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain" {
  description = "Domain for TLS (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
