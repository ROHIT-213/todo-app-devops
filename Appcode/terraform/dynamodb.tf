resource "aws_dynamodb_table" "todo_items" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "todo_id"
  
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  # stream_specification {
  #   stream_view_type = "NEW_AND_OLD_IMAGES"
  # }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "todo_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  global_secondary_index {
    name            = "created_at_index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}

resource "aws_dynamodb_table" "user_sessions" {
  name         = "${var.dynamodb_table_name}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name = "${var.dynamodb_table_name}-sessions"
  }
}
