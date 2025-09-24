# IAM Module for Nomad Cluster

# Nomad Server IAM Role
resource "aws_iam_role" "nomad_server" {
  name = "${var.name_prefix}-nomad-server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Nomad Client IAM Role
resource "aws_iam_role" "nomad_client" {
  name = "${var.name_prefix}-nomad-client"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Nomad Server Policy
resource "aws_iam_policy" "nomad_server" {
  name = "${var.name_prefix}-nomad-server-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeKeyPairs",
          "ec2:DescribePlacementGroups",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.name_prefix}/*"
      }
    ]
  })

  tags = var.tags
}

# Nomad Client Policy
resource "aws_iam_policy" "nomad_client" {
  name = "${var.name_prefix}-nomad-client-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeKeyPairs",
          "ec2:DescribePlacementGroups",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.name_prefix}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "nomad_server" {
  role       = aws_iam_role.nomad_server.name
  policy_arn = aws_iam_policy.nomad_server.arn
}

resource "aws_iam_role_policy_attachment" "nomad_client" {
  role       = aws_iam_role.nomad_client.name
  policy_arn = aws_iam_policy.nomad_client.arn
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "nomad_server_ssm" {
  role       = aws_iam_role.nomad_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "nomad_client_ssm" {
  role       = aws_iam_role.nomad_client.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profiles
resource "aws_iam_instance_profile" "nomad_server" {
  name = "${var.name_prefix}-nomad-server"
  role = aws_iam_role.nomad_server.name

  tags = var.tags
}

resource "aws_iam_instance_profile" "nomad_client" {
  name = "${var.name_prefix}-nomad-client"
  role = aws_iam_role.nomad_client.name

  tags = var.tags
}
