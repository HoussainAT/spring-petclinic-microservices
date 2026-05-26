output "public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.owasp_ec2.public_ip
}

output "app_url" {
  description = "Spring PetClinic API Gateway URL"
  value       = "http://${aws_instance.owasp_ec2.public_ip}:8080"
}

output "eureka_url" {
  description = "Eureka Discovery Server URL"
  value       = "http://${aws_instance.owasp_ec2.public_ip}:8761"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${path.module}/owasp-petclinic-key.pem ec2-user@${aws_instance.owasp_ec2.public_ip}"
}
