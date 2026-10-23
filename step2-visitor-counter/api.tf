############################################
# バックエンド：Lambda + DynamoDB（Step 2 で追加）
############################################

# ---------- DynamoDB：カウント数を保存するテーブル ----------

resource "aws_dynamodb_table" "counter" {
  name     = "${var.project}-counter"
  hash_key = "pk"

  # 「常に無料」枠（読み書き各25ユニットまで）に収めるため、オンデマンドではなくプロビジョンドにする
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "pk"
    type = "S"
  }
}

# ---------- Lambda のコードを zip にまとめる ----------

data "archive_file" "counter" {
  type        = "zip"
  source_file = "${path.module}/lambda/app.py"
  output_path = "${path.module}/build/counter.zip"
}

# ---------- Lambda に与える IAM ロール ----------

# 「Lambda サービスがこのロールを引き受けてよい」という信頼ポリシー
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "counter" {
  name               = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# 最小権限：このテーブルの読み書きと、このロググループへの書き込みだけ
data "aws_iam_policy_document" "counter" {
  statement {
    sid       = "CounterTableReadWrite"
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.counter.arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.counter.arn}:*"]
  }
}

resource "aws_iam_role_policy" "counter" {
  name   = "${var.project}-lambda-policy"
  role   = aws_iam_role.counter.id
  policy = data.aws_iam_policy_document.counter.json
}

# ---------- ログの保存先 ----------

# 先に作っておき、保存期間を7日に制限する（放っておくと無期限に溜まるため）
resource "aws_cloudwatch_log_group" "counter" {
  name              = "/aws/lambda/${var.project}-counter"
  retention_in_days = 7
}

# ---------- Lambda 関数 ----------

resource "aws_lambda_function" "counter" {
  function_name = "${var.project}-counter"
  role          = aws_iam_role.counter.arn

  runtime     = "python3.13"
  handler     = "app.handler"
  memory_size = 128
  timeout     = 5

  filename         = data.archive_file.counter.output_path
  source_code_hash = data.archive_file.counter.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.counter.name
    }
  }

  depends_on = [
    aws_iam_role_policy.counter,
    aws_cloudwatch_log_group.counter,
  ]
}

# ---------- 関数URL：Lambda を直接 HTTPS で呼べるようにする ----------
# API Gateway の代わりに使う。追加料金がかからず、学習用には十分

resource "aws_lambda_function_url" "counter" {
  function_name      = aws_lambda_function.counter.function_name
  authorization_type = "NONE"

  # このサイト（CloudFront のドメイン）からのブラウザアクセスだけを許可する
  cors {
    allow_origins = ["https://${aws_cloudfront_distribution.site.domain_name}"]
    allow_methods = ["GET", "POST"]
    max_age       = 300
  }
}

# 関数URLを誰でも呼べるようにする権限（2025年10月以降は、次の2つが両方必要）
resource "aws_lambda_permission" "url_invoke_url" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.counter.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "url_invoke_function" {
  statement_id             = "FunctionURLInvokeAllowPublicAccess"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.counter.function_name
  principal                = "*"
  invoked_via_function_url = true # 関数URL経由の呼び出しに限定する
}
