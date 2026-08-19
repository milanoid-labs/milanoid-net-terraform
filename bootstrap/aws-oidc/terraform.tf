terraform {
  required_version = ">= 1.12.0"

  backend "s3" {
    bucket       = local.bucket_name
    key          = "milanoid-net-terraform/bootstrap/terraform.tfstate"
    use_lockfile = true
    region       = "eu-central-1"
    profile      = "milanoid" # this will work on my machine only, if tofu running in CI it won't work
    encrypt      = true       # to make it explicit, S3 default encryption is enabled in AWS
  }



  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.60.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  profile = "milanoid"
  region  = "eu-central-1"
}

provider "github" {
  owner = "milanoid-labs"
}

locals {
  aws_region  = "eu-central-1"
  repository  = "milanoid-net-terraform"
  bucket_name = "milanoid-labs-terraform-tofu-state"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions_plan" {
  name = "milanoid-net-terraform-ci-plan"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:milanoid-labs/milanoid-net-terraform:pull_request"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_plan_s3" {
  name = "state-read-only"
  role = aws_iam_role.github_actions_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::milanoid-labs-terraform-tofu-state"
        Condition = {
          StringLike = {
            "s3:prefix" = "milanoid-net-terraform/*"
          }
        }
      },
      {
        Sid      = "ReadState"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::milanoid-labs-terraform-tofu-state/milanoid-net-terraform/terraform.tfstate"
      },
      {
        Sid    = "LockState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "arn:aws:s3:::milanoid-labs-terraform-tofu-state/milanoid-net-terraform/terraform.tfstate.tflock"
      },
    ]
  })
}

resource "aws_iam_role" "github_actions_apply" {
  name = "milanoid-net-terraform-ci-apply"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:milanoid-labs/milanoid-net-terraform:ref:refs/heads/main"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_apply_s3" {
  name = "state-read-apply"
  role = aws_iam_role.github_actions_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::milanoid-labs-terraform-tofu-state"
        Condition = {
          StringLike = {
            "s3:prefix" = "milanoid-net-terraform/*"
          }
        }
      },
      {
        Sid    = "ReadState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = "arn:aws:s3:::milanoid-labs-terraform-tofu-state/milanoid-net-terraform/terraform.tfstate"
      },
      {
        Sid    = "LockState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "arn:aws:s3:::milanoid-labs-terraform-tofu-state/milanoid-net-terraform/terraform.tfstate.tflock"
      },
    ]
  })
}


resource "github_actions_variable" "aws_region" {
  repository    = local.repository
  variable_name = "AWS_REGION"
  value         = local.aws_region
}

resource "github_actions_variable" "aws_tofu_state_bucket" {
  repository    = local.repository
  variable_name = "AWS_TOFU_STATE_BUCKET"
  value         = local.bucket_name
}

resource "github_actions_variable" "aws_plan_role_arn" {
  repository    = local.repository
  variable_name = "AWS_PLAN_ROLE_ARN"
  value         = aws_iam_role.github_actions_plan.arn
}

resource "github_actions_variable" "aws_apply_role_arn" {
  repository    = local.repository
  variable_name = "AWS_APPLY_ROLE_ARN"
  value         = aws_iam_role.github_actions_apply.arn
}


output "plan_role_arn" {
  value = aws_iam_role.github_actions_plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.github_actions_apply.arn
}
