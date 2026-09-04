variable "cluster_name" {
    type       = string
}

variable "cluster_version" {
    type       = string
}

variable "project_name" {
    type       = string
}

variable "environment" {
    type       = string
}

variable "vpc_id" {
    type       = string
}

variable "private_subnet_ids" {
    type       = list(string)
}

variable "cluster_role_arn" {
    type       = string
}

variable "node_group_role_arn" {
    type       = string
}

variable "instance_types" {
    type       = list(string)
}

variable "min_size" {
    type       = number
}

variable "max_size" {
    type       = number
}

variable "desired_size" {
    type       = number
}

variable "capacity_type" {
    type       = string
}

variable "public_access_cidrs" {
    type      = list(string)
}