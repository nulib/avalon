if Settings.minio
  require "aws-sdk-s3"

  Aws.config.update(
    s3: {
      endpoint: Settings.minio.endpoint,
      access_key_id: Settings.minio.access,
      secret_access_key: Settings.minio.secret,
      force_path_style: true,
      region: ENV["AWS_REGION"]
    }
  )
end

if Settings.sqs
  require "aws-sdk-sqs"
  Aws.config.update(
    sqs: {
      endpoint: Settings.sqs ? Settings.sqs.endpoint : nil,
      region: ENV["AWS_REGION"]
    }
  )
end
