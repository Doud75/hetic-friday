resource "aws_security_group" "sg_bastion" {
    name        = "SG-Bastion"
    vpc_id = var.vpc_id

    ingress {
        description = "SSH depuis mon IP publique"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.ip_publique]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "SG-Bastion"
    }
}


resource "aws_security_group" "sg_web" {
  name        = "SG-Web"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-Web"
  }
}

resource "aws_security_group" "sg_app" {
  name        = "SG-App"
  description = "SG for App servers"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Port 80 depuis SG-Web"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  ingress {
    description     = "SSH depuis SG-Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_bastion.id]
  }

  ingress {
    description = "ICMP entre les apps"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-App"
  }
}

resource "aws_security_group" "sg_db" {
  name        = "SG-DB"
  description = "SG for Database"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL depuis SG-App"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-DB"
  }
}