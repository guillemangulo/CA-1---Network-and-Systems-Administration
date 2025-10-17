provider "aws" {
	region = "eu-west-1"
}

#I use the one I created manually to test
data "aws_security_group" "CASecGroup" {
	id	= "sg-0a2c7557221084a0b"
}

resource "aws_instance" "CA-1-Instance" {
	ami 			= "ami-033a3fad07a25c231"
	instance_type 		= "t3.micro"
	key_name		= "CAKey"
	vpc_security_group_ids	= [data.aws_security_group.CASecGroup.id]


	tags = {
		Name = "CA-1-Instance"
	}
}


