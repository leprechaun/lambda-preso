variable "prefix" {
  description = "Prefix applied to all resource names"
  type        = string
  default     = "hello-world"
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}
