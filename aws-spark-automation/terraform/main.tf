provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "spark_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "spark-vpc"
  }
}

resource "aws_subnet" "spark_subnet" {
  vpc_id     = aws_vpc.spark_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "spark-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.spark_vpc.id
  tags = {
    Name = "spark-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.spark_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "spark-route-table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.spark_subnet.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "spark_sg" {
  name        = "spark-sg"
  description = "Allow Spark and SSH traffic"
  vpc_id      = aws_vpc.spark_vpc.id

  // SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow all internal traffic within the security group
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  // Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "spark-sg"
  }
}

resource "aws_key_pair" "spark_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "spark_master" {
  ami           = var.ami_id
  instance_type = var.instance_type
  availability_zone = "ap-southeast-1a"
  subnet_id     = aws_subnet.spark_subnet.id
  vpc_security_group_ids = [aws_security_group.spark_sg.id]
  key_name      = aws_key_pair.spark_key.key_name

  tags = {
    Name  = "spark-master"
    spark-cluster = "master"
  }
}

resource "aws_instance" "spark_worker" {
  count         = var.worker_count
  ami           = var.ami_id
  instance_type = var.instance_type
  availability_zone = "ap-southeast-1a"
  subnet_id     = aws_subnet.spark_subnet.id
  vpc_security_group_ids = [aws_security_group.spark_sg.id]
  key_name      = aws_key_pair.spark_key.key_name

  tags = {
    Name  = "spark-worker-${count.index}"
    spark-cluster = "worker"
  }
}

resource "aws_instance" "spark_edge_node" {
  ami           = var.ami_id
  instance_type = var.instance_type
  availability_zone = "ap-southeast-1a"
  subnet_id     = aws_subnet.spark_subnet.id
  vpc_security_group_ids = [aws_security_group.spark_sg.id]
  key_name      = aws_key_pair.spark_key.key_name

  tags = {
    Name  = "spark-edge-node"
    spark-cluster = "client"
  }
}