output "S3FlaskStorage" {
  value = aws_s3_bucket.FlaskStorage.arn
  description = "ARN for FlaskStorage S3 Bucket"
}