variable "platform_name" {}

locals {
  platform_id = "${terraform.workspace == "default" ? var.platform_name : "${var.platform_name}-${terraform.workspace}"}"
}

variable "platform_cidr" {
  default = "10.0.0.0/16"
}

variable "public_cidrs" {
  type    = "list"
  default = ["10.0.0.0/19"]
}

variable "operator_cidrs" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "public_access_cidrs" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "compute_node_count" {
  default = 1
}

data "aws_availability_zones" "available" {}
