output "pipeline_names" {
  value = { for k, v in aws_codepipeline.service : k => v.name }
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "codebuild_role_arn" {
  value = aws_iam_role.codebuild.arn
}
