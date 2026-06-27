output "my_ec2_public_ip" {
    value = module.my_app-server.instance.public_ip
}