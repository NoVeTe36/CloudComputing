variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-1a"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instances (Ubuntu 20.04 recommended)."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "worker_count" {
  description = "The number of Spark worker nodes."
  type        = number
  default     = 4
}

variable "key_name" {
  description = "The name of the SSH key pair to use."
  type        = string
}

variable "public_key_path" {
  description = "The path to the public SSH key."
  type        = string
}