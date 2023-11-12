output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_id" {
  description = "EKS Cluster ID"
  value = module.eks.cluster_id
}

output "cluster_version" {
  description = "EKS Cluster version"
  value = module.eks.cluster_version
}