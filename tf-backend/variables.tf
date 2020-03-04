variable "tf_state_bucket" {
  type        = string
  description = "s3 bucket name for your TerraForm state"
}

variable "profile" {
  type        = string
  description = "AWS profile to use (required)"
}
