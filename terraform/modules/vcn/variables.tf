variable "compartment_id" {
  description = "Compartment OCID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "ssh_source_cidr" {
  description = "CIDR block allowed for SSH access (default: anywhere - CHANGE for production)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "admin_source_cidr" {
  description = "CIDR block allowed for K8s API access (default: anywhere - CHANGE for production)"
  type        = string
  default     = "0.0.0.0/0"
}
