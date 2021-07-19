locals {
  queues = {
    # queue name => visibility timeout in seconds
    batch_ingest                    = 3600,
    bulk_access_control             = 300,
    create_encode                   = 30,
    default                         = 300,
    delete_course                   = 300,
    extract_still                   = 60,
    ingest_finished_job             = 30,
    ingest_status_job               = 30,
    ingest                          = 300,
    master_file_management_delete   = 30,
    master_file_management_move     = 60,
    reindex                         = 43200,
    s3_split                        = 600,
    solr_backup                     = 30,
    update_dependent_permalinks     = 300,
    waveform                        = 300
  }
}

resource "aws_sqs_queue" "avr_dead_letter_queue" {
  name     = "${var.app_name}-dead_letter_queue"
}
resource "aws_sqs_queue" "active_job_queue" {
  for_each                      = local.queues
  name                          = "${var.app_name}-${each.key}"
  visibility_timeout_seconds    = each.value
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.avr_dead_letter_queue.arn
    maxReceiveCount     = 5
  })
}
