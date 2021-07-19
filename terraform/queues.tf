locals {
  queue_names = [
    "batch_ingest", "bulk_access_control", "create_encode", "default", "delete_course",
    "extract_still", "ingest_finished_job", "ingest_status_job", "ingest", "master_file_management_delete",
    "master_file_management_move", "reindex", "s3_split", "solr_backup", "update_dependent_permalinks",
    "waveform"
  ]
}

resource "aws_sqs_queue" "avr_dead_letter_queue" {
  name     = "${var.app_name}-dead_letter_queue"
}
resource "aws_sqs_queue" "active_job_queue" {
  for_each       = toset(local.queue_names)
  name           = "${var.app_name}-${each.key}"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.avr_dead_letter_queue.arn
    maxReceiveCount     = 5
  })
}