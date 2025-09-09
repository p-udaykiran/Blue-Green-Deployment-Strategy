# -------------------------------
# Provider Configuration
# -------------------------------
provider "aws" {
  region = "ap-south-1"  # Set AWS region (Mumbai)
}

# -------------------------------
# Networking Resources
# -------------------------------

# Create a VPC with CIDR block 10.0.0.0/16
resource "aws_vpc" "uday_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "uday-vpc"
  }
}

# Create 2 public subnets in different Availability Zones
resource "aws_subnet" "uday_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.uday_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.uday_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true   # Auto-assign public IPs to EC2 in subnet

  tags = {
    Name = "uday-subnet-${count.index}"
  }
}

# Create an Internet Gateway for VPC
resource "aws_internet_gateway" "uday_igw" {
  vpc_id = aws_vpc.uday_vpc.id

  tags = {
    Name = "uday-igw"
  }
}

# Create a Route Table for Internet access
resource "aws_route_table" "uday_route_table" {
  vpc_id = aws_vpc.uday_vpc.id

  route {
    cidr_block = "0.0.0.0/0"                  # Default route to Internet
    gateway_id = aws_internet_gateway.uday_igw.id
  }

  tags = {
    Name = "uday-route-table"
  }
}

# Associate subnets with Route Table (so they become public)
resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.uday_subnet[count.index].id
  route_table_id = aws_route_table.uday_route_table.id
}

# -------------------------------
# Security Groups
# -------------------------------

# Security Group for EKS Control Plane (Cluster SG)
resource "aws_security_group" "uday_cluster_sg" {
  vpc_id = aws_vpc.uday_vpc.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "uday-cluster-sg"
  }
}

# Security Group for EKS Worker Nodes (Node SG)
resource "aws_security_group" "uday_node_sg" {
  vpc_id = aws_vpc.uday_vpc.id

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "uday-node-sg"
  }
}

# -------------------------------
# EKS Cluster
# -------------------------------

# Create the EKS Cluster
resource "aws_eks_cluster" "uday" {
  name     = "uday-cluster"
  role_arn = aws_iam_role.uday_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.uday_subnet[*].id
    security_group_ids = [aws_security_group.uday_cluster_sg.id]
  }
}

# Create Node Group (worker nodes for EKS cluster)
resource "aws_eks_node_group" "uday" {
  cluster_name    = aws_eks_cluster.uday.name
  node_group_name = "uday-node-group"
  node_role_arn   = aws_iam_role.uday_node_group_role.arn
  subnet_ids      = aws_subnet.uday_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t2.medium"]   # EC2 instance type for worker nodes

  remote_access {
    ec2_ssh_key               = var.ssh_key_name  # SSH key for accessing nodes
    source_security_group_ids = [aws_security_group.uday_node_sg.id]
  }
}

# -------------------------------
# IAM Roles & Policies
# -------------------------------

# IAM Role for EKS Cluster
resource "aws_iam_role" "uday_cluster_role" {
  name = "uday-cluster-role"

  # Allow EKS service to assume this role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach AmazonEKSClusterPolicy to cluster role
resource "aws_iam_role_policy_attachment" "uday_cluster_role_policy" {
  role       = aws_iam_role.uday_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM Role for Node Group
resource "aws_iam_role" "uday_node_group_role" {
  name = "uday-node-group-role"

  # Allow EC2 service to assume this role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach policies required by EKS worker nodes
resource "aws_iam_role_policy_attachment" "uday_node_group_role_policy" {
  role       = aws_iam_role.uday_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "uday_node_group_cni_policy" {
  role       = aws_iam_role.uday_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "uday_node_group_registry_policy" {
  role       = aws_iam_role.uday_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
