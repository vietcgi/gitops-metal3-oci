output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.main.id
}

output "public_subnet_id" {
  description = "Public subnet OCID"
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet OCID"
  value       = oci_core_subnet.private.id
}

output "control_plane_nsg_id" {
  description = "Control plane NSG OCID"
  value       = oci_core_network_security_group.control_plane.id
}

output "internet_gateway_id" {
  description = "Internet gateway OCID"
  value       = oci_core_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT gateway OCID"
  value       = oci_core_nat_gateway.main.id
}
