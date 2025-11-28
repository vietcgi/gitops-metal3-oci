variable "tenancy_id" {
  description = "Tenancy OCID"
  type        = string
}

variable "compartment_id" {
  description = "Compartment OCID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "github_owner" {
  description = "GitHub owner/org for OIDC"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repo name for OIDC"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
