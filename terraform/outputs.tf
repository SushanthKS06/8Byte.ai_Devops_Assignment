output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_instance.app.public_ip}:3000"
}
