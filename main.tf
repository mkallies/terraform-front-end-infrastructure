terraform {
  required_version = "~> 0.12.20"

  # Change this for your own stuff!
  backend "s3" {
    bucket = "tf-backend-kallies-state"
    key    = "tf/state-files/michaelkallies.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  version = "~> 2.35"
  region  = "us-east-1"
  profile = var.profile
}

/* 

Setup s3 bucket

We've attached a policy that is needed for an s3 website
Includes `Allow` effect for any principal and a `GetObject` action
Make the resource available so the policy matches the bucket

*/

resource "aws_s3_bucket" "bucket_site" {
  bucket = var.bucket_name
  acl    = "public-read"
  policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[{
        "Sid":"PublicReadForGetBucketObjects",
        "Effect":"Allow",
          "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::${var.bucket_name}/*"]
    }
  ]
}
EOF

  force_destroy = true

  # This tells AWS that we want a website
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

// Create ACM certificate - consider this 'async' we do not wait for the cert to be issued here

resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Environment = "Test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

/*

Validation portion - this allows us to wait for the cert to be issued

from the docs:

This resource represents a successful validation of an ACM certificate in concert with other resources.

Most commonly, this resource is used together with `aws_route53_record` and `aws_acm_certificate` to request a 
DNS validated certificate, deploy the required validation records and wait for validation to complete.

*/

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

// Setup Route53

data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.zone.zone_id
  records = [aws_acm_certificate.cert.domain_validation_options.0.resource_record_value]

  ttl = 60
}

locals {
  s3_origin_id = "mys3-origin"
}

// Create CloudFront Distribution
// CloudFront distributions can take about 20 minutes to deploy after creation or modification

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket_site.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "michael-test"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "${var.bucket_name}.s3.amazonaws.com"
    prefix          = "cloudfront_logs"
  }

  aliases = [var.domain_name, "www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

  }

  # required
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }
}

// A record needed for pointing a domain name to an IP address
// eg. michaelkallies.com -> A record -> 132.32.33.10

resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

// Create a Route 53 CNAME record to redirect www.domain.com to domain.com
// CNAME record points to another name instead of an IP
// www.michaelkallies.com -> CNAME record -> michaelkallies.com
// CNAME can point to an A record or another CNAME

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = "300"

  records = [aws_cloudfront_distribution.s3_distribution.domain_name]
}
