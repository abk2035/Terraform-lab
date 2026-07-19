# --- 1. CONFIGURATION DU PROFIL IAM POUR EC2 (SSM CAPABILITY) ---

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.environment}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2_ssm.name
}

# --- 2. APPLICATION LOAD BALANCER & TARGET GROUP ---

resource "aws_lb" "alb" {
  name               = "${var.environment}-wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "${var.environment}-wordpress-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.environment}-wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200,301,302" # Évite la boucle de destruction infinie de l'ASG
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# --- 3. LAUNCH TEMPLATE & AUTO SCALING GROUP ---

resource "aws_launch_template" "tpl" {
  name_prefix   = "${var.environment}-wordpress-tpl-"
  image_id      = "ami-01edba92f9036f76e" # Remplacer par un AMI Amazon Linux 3 à jour dans ta région
  instance_type = "t3.micro"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = false # Sécurité maximale : instances dans les subnets privés
    security_groups             = [var.ec2_security_group_id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd wget php php-mysqlnd php-gd php-xml php-mbstring amazon-efs-utils
              systemctl start httpd
              systemctl enable httpd
              
              mkdir -p /var/www/html/wp-content
              mount -t efs -o tls ${var.efs_id}:/ /var/www/html/wp-content
              echo "${var.efs_id}:/ /var/www/html/wp-content efs defaults,_netdev,tls 0 0" >> /etc/fstab
              
              cd /var/www/html
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz --strip-components=1
              rm latest.tar.gz
              
              cp wp-config-sample.php wp-config.php
              
              sed -i "s/database_name_here/wordpress/g" wp-config.php
              sed -i "s/username_here/admin/g" wp-config.php
              sed -i "s/password_here/${var.db_password}/g" wp-config.php
              sed -i "s/localhost/${var.db_endpoint}/g" wp-config.php
              
              chown -R apache:apache /var/www/html
              chmod -R 755 /var/www/html
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name_prefix         = "${var.environment}-asg-"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.tg.arn]
  
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.tpl.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-wordpress-app"
    propagate_at_launch = true
  }
}

# --- 4. CONFIGURATION DE LA DISTRIBUTION CLOUDFRONT ---

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Distribution CDN pour le WordPress modulaire"
  aliases             = [var.domain_name]

  origin {
    domain_name = aws_lb.alb.dns_name
    origin_id   = "ALB-WordPress"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only" # CloudFront communique avec l'ALB en HTTP
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-WordPress"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Authorization"] # Crucial pour le fonctionnement multi-site/WordPress

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Environment = var.environment }
}