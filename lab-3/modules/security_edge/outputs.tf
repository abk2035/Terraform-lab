output "acm_certificate_arn" {
  value       = aws_acm_certificate.cert.arn
  description = "L'ARN du certificat à passer à la distribution CloudFront"
}