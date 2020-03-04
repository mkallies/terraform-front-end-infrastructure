variable "bucket_name" {
  type        = string
  description = "s3 bucket name"
}

variable "domain_name" {
  type        = string
  description = "Domain name (use domain.com and NOT www.domain.com)"
}

variable "profile" {
  type        = string
  description = "AWS profile to use (required)"
}

