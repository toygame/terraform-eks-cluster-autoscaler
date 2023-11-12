##############################################################
# Cluster Autoscaler
##############################################################
locals {
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler"
  tags = {
    Owner = "terraform"
  }
}

resource "helm_release" "cluster-autoscaler" {
  name             = "cluster-autoscaler"
  namespace        = local.k8s_service_account_namespace
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = "9.29.3"
  create_namespace = false

  set {
    name  = "awsRegion"
    value = var.region
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = local.k8s_service_account_name
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_admin.iam_role_arn
    type  = "string"
  }
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "autoDiscovery.enabled"
    value = "true"
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
}

module "iam_assumable_role_admin" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 4.0"
  create_role                   = true
  role_name                     = "cluster-autoscaler-${var.cluster_name}"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.k8s_service_account_namespace}:${local.k8s_service_account_name}"]
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name_prefix = "cluster-autoscaler"
  description = "EKS cluster-autoscaler policy for cluster ${module.eks.cluster_id}"
  policy      = data.aws_iam_policy_document.cluster_autoscaler.json
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "clusterAutoscalerAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "clusterAutoscalerOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${module.eks.cluster_id}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}

################################################################################
# Supporting Resources
################################################################################
resource "aws_iam_policy" "node_additional" {
  name        = "${var.cluster_name}-additional"
  description = "${var.cluster_name} node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}

################################################################################
# Tags for the ASG to support cluster-autoscaler scale up from 0 for nodegroup2
################################################################################

locals {

  eks_asg_tag_list_nodegroup1 = {
    "k8s.io/cluster-autoscaler/enabled" : true
    "k8s.io/cluster-autoscaler/${var.cluster_name}" : "owned"
    "k8s.io/cluster-autoscaler/node-template/label/asg-group" : var.nodegroup1_label
  }

  eks_asg_tag_list_nodegroup2 = {
    "k8s.io/cluster-autoscaler/enabled" : true
    "k8s.io/cluster-autoscaler/${var.cluster_name}" : "owned"
    "k8s.io/cluster-autoscaler/node-template/label/asg-group" : var.nodegroup2_label
    "k8s.io/cluster-autoscaler/node-template/taint/dedicated" : "${var.nodegroup2_label}:NoSchedule"
  }

}

resource "aws_autoscaling_group_tag" "nodegroup1" {
  for_each               = local.eks_asg_tag_list_nodegroup1
  autoscaling_group_name = element(module.eks.eks_managed_node_groups_autoscaling_group_names, 0)

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group_tag" "nodegroup2" {
  for_each               = local.eks_asg_tag_list_nodegroup2
  autoscaling_group_name = element(module.eks.eks_managed_node_groups_autoscaling_group_names, 1)

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = true
  }
}
