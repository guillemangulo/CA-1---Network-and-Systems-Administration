provider "aws" {
	region = "eu-west-1"
}

resource "aws_security_group" "CA-SG" {
  name        = "CA-SG"
  description = "Allow SSH (22) and HTTP (80)"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
	# full open, this just for this project, in real environment wouldn't be like that
    cidr_blocks = ["0.0.0.0/0"] 
  }

	# same for http
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "CA-SG"
  }
}

resource "aws_instance" "CA-1-Instance" {
	ami 			= "ami-033a3fad07a25c231"
	instance_type 		= "t3.micro"
	key_name		= "CAKey"
	vpc_security_group_ids	= [aws_security_group.CA-SG.id]


	tags = {
		Name = "CA-1-Instance"
	}
}

output "instance_ip" {
  description = "Public IP from EC2 instance"
  value       = aws_instance.CA-1-Instance.public_ip
}

