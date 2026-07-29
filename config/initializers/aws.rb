if Settings.minio
  require "aws-sdk-s3"

  Aws.config.update(
    endpoint: Settings.minio.endpoint,
    access_key_id: Settings.minio.access,
    secret_access_key: Settings.minio.secret,
    region: ENV["AWS_REGION"]
  )

  # Service specific global configuration
  Aws.config[:s3] = { force_path_style: true }
end

# AVR: point the SQS client at a non-default endpoint (ElasticMQ, LocalStack)
# when one is configured. Scoped to :sqs rather than set globally so it can't
# affect the S3, SSM, or CloudFront clients.
if Settings.sqs
  require "aws-sdk-sqs"

  Aws.config.update(
    sqs: {
      endpoint: Settings.sqs.endpoint,
      region: ENV["AWS_REGION"]
    }
  )
end
