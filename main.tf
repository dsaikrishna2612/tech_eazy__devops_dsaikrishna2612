resource "aws_instance" "server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.sub1.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = var.env_name
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = var.ssh_private_key
    host        = self.public_ip
  }

  # Copy scripts
  provisioner "file" {
    source      = "install.sh"
    destination = "/home/ec2-user/install.sh"
  }

  provisioner "file" {
    source      = "upload_logs.sh"
    destination = "/home/ec2-user/upload_logs.sh"
  }

  # Run scripts
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/install.sh",
      "chmod +x /home/ec2-user/upload_logs.sh",
      "sudo /home/ec2-user/install.sh",
      "sudo /home/ec2-user/upload_logs.sh"
    ]
  }
}