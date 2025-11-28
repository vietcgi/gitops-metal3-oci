output "bucket_name" {
  description = "Bucket name"
  value       = oci_objectstorage_bucket.state.name
}

output "bucket_namespace" {
  description = "Bucket namespace"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "bucket_id" {
  description = "Bucket OCID"
  value       = oci_objectstorage_bucket.state.id
}

output "backup_par_url" {
  description = "Pre-authenticated URL for backups"
  value       = var.create_backup_par ? oci_objectstorage_preauthrequest.backup[0].full_path : null
  sensitive   = true
}
