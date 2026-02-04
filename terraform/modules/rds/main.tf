resource "aws_db_subnet_group" "rdssubnetgroup" {
  name       = "grp2-db-subnet-group"
  subnet_ids = var.subnets

  tags = {
    Name        = "grp2-db-subnet-group"
  }
  
}

resource "aws_db_instance" "grp2dbinstance" {
  identifier     = "grp2dbinstance"
  instance_class = "db.t3.micro"
  engine         = "postgres"
  engine_version = "17.6"
  allocated_storage = 20
  storage_type = "gp2"
  multi_az = true
  db_name = "grp2db"
  username  = var.db_username
  password  = var.db_password
  vpc_security_group_ids = [var.SG-DB]
  db_subnet_group_name = aws_db_subnet_group.rdssubnetgroup.name
  skip_final_snapshot = true

  tags = {
        Name = "grp2-rds-instance"
    } 
}