module "vpc" {
  source               = "../../modules/vpc"
  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.repository_name
}

module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  project_name    = var.project_name
  environment     = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_role_arn    = module.iam.cluster_role_arn
  node_group_role_arn = module.iam.node_role_arn

  instance_types = var.instance_types
  capacity_type  = var.capacity_type

  min_size     = var.min_size
  max_size     = var.max_size
  desired_size = var.desired_size

  public_access_cidrs = var.public_access_cidrs
}