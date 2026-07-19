# Création du certificat SSL dans la région us-east-1 (Requis pour CloudFront)
resource "aws_acm_certificate" "cert" {
  provider          = aws.us-east-1
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name        = "${var.environment}-wordpress-cert"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}