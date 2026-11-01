output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.app_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security group attached to the application EC2 instance"
  value       = aws_security_group.app_sg.id
}

output "instance_id" {
  description = "ID of the application EC2 instance"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IPv4 address used by the public EC2 deployment workflow"
  value       = aws_instance.app_server.public_ip
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion Host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Bastion Host EC2 instance ID"
  value       = aws_instance.bastion.id
}

output "private_instance_id" {
  description = "Private application EC2 instance ID"
  value       = aws_instance.private_app_server.id
}

output "private_instance_ip" {
  description = "Private IP address of the application EC2"
  value       = aws_instance.private_app_server.private_ip
}

output "application_url" {
  description = "Flask application URL after the app deployment workflow succeeds"
  value       = "http://${aws_instance.app_server.public_ip}:5000"
}
