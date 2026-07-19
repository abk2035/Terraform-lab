output "cloudfront_dns" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "L'URL CloudFront à utiliser pour configurer ton CNAME chez ton registrar"
}