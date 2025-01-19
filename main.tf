provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

resource "aws_security_group" "instancesg" {
  name = "instancesg-terraform"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "example" {
  name          = "example-launch-template"
  image_id      = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"

  network_interfaces {
    security_groups = [aws_security_group.instancesg.id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y nginx
echo "<html><body><h1>Hello World from Nginx on EC2!</h1></body></html>" | sudo tee /var/www/html/index.html
sudo systemctl start nginx
sudo systemctl enable nginx
EOF
  )
}

resource "aws_autoscaling_group" "example" {
  desired_capacity     = 2
  min_size             = 2
  max_size             = 10
  vpc_zone_identifier  = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}
