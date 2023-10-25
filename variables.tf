variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "Cluster name"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_version" {
  description = "Cluster version"
  type        = string
  default     = "1.25"
}

variable "nodegroup1_label" {
  description = "Nodegroup label"
  type        = string
  default     = "group1"
}

variable "nodegroup2_label" {
  description = "Nodegroup label"
  type        = string
  default     = "group1"
}

