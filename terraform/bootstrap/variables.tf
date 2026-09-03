variable "aws_region" {
  type    = string
  default = ""
}

variable "aws_profile" {
  type    = string
  default = ""
}

variable "repository_name" {
  type    = string
  default = ""
}

variable "project_name" {
  type    = string
  default = ""
}

variable "state_bucket_name" {
  type        = string
  description = "Name of the S3 bucket to store Terraform state"
}