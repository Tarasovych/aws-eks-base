locals {
  asg_tags = [tomap({ "key" = "k8s.io/cluster-autoscaler/enabled", "propagate_at_launch" = "false", "value" = "true" }),
  tomap({ "key" = "k8s.io/cluster-autoscaler/${local.name}", "propagate_at_launch" = "false", "value" = "true" })]

  asg_ci_tags      = [tomap({ "key" = "k8s.io/cluster-autoscaler/node-template/label/purpose", "propagate_at_launch" = "true", "value" = "ci" })]
  fargate_tags     = tomap({ "tags" = { "lifecycle" = "fargate" } })
  fargate_subnets  = tomap({ "subnet" = module.vpc.private_subnets })
  fargate_profiles = var.create_fargate_profiles ? { for profile_name, profile_value in var.eks_fargate_profiles : profile_name => merge(profile_value, local.fargate_subnets, local.fargate_tags) } : {}
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "15.1.0"

  cluster_name                                       = local.name
  cluster_version                                    = var.eks_cluster_version
  subnets                                            = module.vpc.intra_subnets
  enable_irsa                                        = true
  worker_create_cluster_primary_security_group_rules = true

  tags = {
    ClusterName = local.name
    Environment = local.env
  }

  vpc_id = module.vpc.vpc_id

  worker_groups_launch_template = [
    {
      name                    = "spot"
      override_instance_types = var.eks_worker_groups.spot.override_instance_types
      spot_instance_pools     = var.eks_worker_groups.spot.spot_instance_pools
      asg_max_size            = var.eks_worker_groups.spot.asg_max_size
      asg_min_size            = var.eks_worker_groups.spot.asg_min_size
      asg_desired_capacity    = var.eks_worker_groups.spot.asg_desired_capacity
      subnets                 = module.vpc.private_subnets
      kubelet_extra_args      = "--node-labels=node.kubernetes.io/lifecycle=spot"
      public_ip               = false
      additional_userdata     = file("${path.module}/templates/eks-x86-nodes-userdata.sh")
      tags                    = local.asg_tags
    },
    {
      name                 = "ondemand"
      instance_type        = var.eks_worker_groups.ondemand.instance_type
      asg_desired_capacity = var.eks_worker_groups.ondemand.asg_desired_capacity
      subnets              = module.vpc.private_subnets
      asg_max_size         = var.eks_worker_groups.ondemand.asg_max_size
      cpu_credits          = "unlimited"
      kubelet_extra_args   = "--node-labels=node.kubernetes.io/lifecycle=ondemand"
      public_ip            = false
      additional_userdata  = file("${path.module}/templates/eks-x86-nodes-userdata.sh")
      tags                 = local.asg_tags
    },
    {
      name                    = "ci"
      override_instance_types = var.eks_worker_groups.ci.override_instance_types
      spot_instance_pools     = var.eks_worker_groups.ci.spot_instance_pools
      asg_max_size            = var.eks_worker_groups.ci.asg_max_size
      asg_min_size            = var.eks_worker_groups.ci.asg_min_size
      asg_desired_capacity    = var.eks_worker_groups.ci.asg_desired_capacity
      subnets                 = module.vpc.public_subnets
      cpu_credits             = "unlimited"
      kubelet_extra_args      = "--node-labels=node.kubernetes.io/lifecycle=spot --node-labels=purpose=ci --register-with-taints=purpose=ci:NoSchedule"
      public_ip               = true
      additional_userdata     = file("${path.module}/templates/eks-x86-nodes-userdata.sh")
      tags                    = concat(local.asg_tags, local.asg_ci_tags)
    },
  ]

  fargate_profiles = local.fargate_profiles

  map_roles = local.eks_map_roles

  write_kubeconfig = var.eks_write_kubeconfig
}
