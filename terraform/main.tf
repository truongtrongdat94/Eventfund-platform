locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── GitHub Actions OIDC Provider ────────────────────────────────────────────
module "github_oidc" {
  source = "./modules/oidc"
  tags   = local.common_tags
}

module "github_actions_role" {
  source = "./modules/github_actions_role"

  role_name         = var.github_actions_role_name
  oidc_provider_arn = module.github_oidc.oidc_provider_arn
  github_repos      = var.github_repos
  tags              = local.common_tags
  # depends_on thừa vì đã có reference trực tiếp qua oidc_provider_arn
  # Terraform tự detect implicit dependency
}

module "s3_security_reports" {
  source = "./modules/s3_security_reports"

  bucket_name    = var.security_reports_bucket
  retention_days = var.security_reports_retention_days
  tags           = local.common_tags
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  azs                  = var.azs
}

module "eks" {
  source = "./modules/eks"

  cluster_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  eks_version           = var.eks_version
  node_instance_types   = var.node_group_instance_types
  node_desired_capacity = var.node_desired_capacity
  node_min_capacity     = var.node_min_capacity
  node_max_capacity     = var.node_max_capacity
  node_capacity_type    = var.node_capacity_type
  node_ami_type         = var.node_ami_type
  node_disk_size        = var.node_disk_size
  node_max_unavailable  = var.node_max_unavailable
  node_repair_enabled   = var.node_repair_enabled

  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_public_access_cidrs     = var.cluster_public_access_cidrs
  service_ipv4_cidr               = var.service_ipv4_cidr
  cluster_log_types               = var.cluster_log_types
  authentication_mode             = var.authentication_mode
  bootstrap_admin_permissions     = var.bootstrap_admin_permissions
  admin_user_arns                 = var.admin_user_arns
  # implicit dependency: module.vpc qua vpc_id, private_subnet_ids, public_subnet_ids
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = [var.ecr_backend_repo]
}

module "frontend" {
  source = "./modules/frontend"

  project_name = var.project_name
  environment  = var.environment
}

# ─── Chờ EKS API server và nodes sẵn sàng ────────────────────────────────────
# EKS state = ACTIVE không có nghĩa là API server đã nhận request
# Node group cũng cần thêm thời gian để join cluster
# 60s đủ để API server ready và IAM OIDC propagate trên AWS side
resource "time_sleep" "wait_for_eks" {
  depends_on      = [module.eks]
  create_duration = "120s"
}

module "iam" {
  source = "./modules/iam"

  project_name      = var.project_name
  region            = var.region
  oidc_provider_arn = module.eks.oidc_provider_arn  # EKS OIDC, không phải GitHub OIDC
  oidc_provider_url = module.eks.oidc_provider_url
  ssm_prefix        = var.ssm_prefix

  depends_on = [time_sleep.wait_for_eks]
}

module "helm" {
  source = "./modules/helm"

  cluster_name            = module.eks.cluster_name
  region                  = var.region
  vpc_id                  = module.vpc.vpc_id
  alb_controller_role_arn = module.iam.alb_controller_role_arn
  eso_role_arn            = module.iam.eso_role_arn
  autoscaler_role_arn     = module.iam.autoscaler_role_arn
  argocd_repo_url         = var.argocd_repo_url
  argocd_target_revision  = var.argocd_target_revision
  argocd_app_namespace    = var.argocd_app_namespace

  # module.vpc: tường minh dù đã có implicit qua vpc_id
  # module.eks + module.iam: bắt buộc vì Helm cần cluster ready và IAM roles tồn tại
  # time_sleep: đảm bảo API server sẵn sàng nhận Helm
  depends_on = [time_sleep.wait_for_eks, module.iam, module.vpc]
}
