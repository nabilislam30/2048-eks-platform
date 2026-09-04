module "eks" {
    source         = "terraform-aws-modules/eks/aws"
    version        = "21.25.0"


    name = var.cluster_name
    kubernetes_version = var.cluster_version

    vpc_id = var.vpc_id
    subnet_ids = var.private_subnet_ids

    create_iam_role = false
    iam_role_arn = var.cluster_role_arn

    endpoint_private_access = true
    endpoint_public_access  = true
    endpoint_public_access_cidrs = var.public_access_cidrs

    enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
]

enable_cluster_creator_admin_permissions = true

eks_managed_node_groups = {
    default = {
        subnet_ids = var.private_subnet_ids

        create_iam_role = false
        iam_role_arn = var.node_group_role_arn

        instance_types = var.instance_types
        capacity_type = var.capacity_type

        min_size     = var.min_size
        max_size     = var.max_size
        desired_size = var.desired_size
    }
}

    tags = {
        "Project"     = var.project_name
        "Environment" = var.environment
    }
}