################################################################################
# EKS Module
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.26.6"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_enabled_log_types       = ["api", "controllerManager", "scheduler"]
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_tags = {
    Name = var.cluster_name
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth_configmap = true

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_group_defaults = {
    ami_type                   = "AL2_x86_64"
    disk_size                  = 10
    iam_role_attach_cni_policy = true
    enable_monitoring          = true
  }

  eks_managed_node_groups = {

    nodegroup1 = {
      desired_size   = 1
      max_size       = 2
      min_size       = 1
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      update_config = {
        max_unavailable_percentage = 50
      }
      labels = {
        asg-group = var.nodegroup1_label
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"                       = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}"           = "owned"
        "k8s.io/cluster-autoscaler/node-template/label/asg-group" = "${var.nodegroup1_label}"
      }
    }

    nodegroup2 = {
      desired_size   = 0
      max_size       = 10
      min_size       = 0
      instance_types = ["c5.xlarge", "c5a.xlarge", "m5.xlarge", "m5a.xlarge"]
      capacity_type  = "SPOT"
      update_config = {
        max_unavailable_percentage = 100
      }
      labels = {
        asg-group = var.nodegroup2_label
      }
      taints = [
        {
          key    = "dedicated"
          value  = var.nodegroup2_label
          effect = "NO_SCHEDULE"
        }
      ]
      tags = {
        "k8s.io/cluster-autoscaler/enabled"                       = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}"           = "owned"
        "k8s.io/cluster-autoscaler/node-template/taint/dedicated" = "${var.nodegroup2_label}:NoSchedule"
        "k8s.io/cluster-autoscaler/node-template/label/asg-group" = "${var.nodegroup2_label}"
      }
    }
  }

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = module.eks.eks_managed_node_groups

  policy_arn = aws_iam_policy.node_additional.arn
  role       = each.value.iam_role_name
}
