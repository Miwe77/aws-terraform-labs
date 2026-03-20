provider "aws" {
  region = "us-east-1"
}

# 1. Base de Datos (DynamoDB)
resource "aws_dynamodb_table" "galeria" {
  name           = "TablaGaleriaImagenes"
  billing_mode   = "PAY_PER_REQUEST" # Súper barato, solo pagas si la usas
  hash_key       = "imageId"

  attribute {
    name = "imageId"
    type = "S" # String
  }
}

# 2. El Bucket de S3 (Para subir las imágenes)
# Usamos un número aleatorio para que el nombre sea único en todo el mundo
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "imagenes" {
  bucket = "lab-serverless-imagenes-${random_id.bucket_id.hex}"
  force_destroy = true
}

# Quitamos los bloqueos de seguridad del bucket de imágenes
resource "aws_s3_bucket_public_access_block" "imagenes_access" {
  bucket = aws_s3_bucket.imagenes.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Hacemos que las fotos se puedan leer desde internet
resource "aws_s3_bucket_policy" "imagenes_policy" {
  bucket = aws_s3_bucket.imagenes.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.imagenes.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.imagenes_access]
}

# 3. Empaquetar el código Node.js en un ZIP (Terraform lo hace por ti)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

# 4. La Función Lambda
resource "aws_lambda_function" "procesador_imagenes" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ProcesadorDeImagenesS3"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.galeria.name
    }
  }
}

# 5. Permisos y Seguridad (IAM) para la Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_s3_dynamo_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Le damos permiso para logs, DynamoDB, S3 y REKOGNITION (IA)
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamo_rekognition_policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = ["dynamodb:PutItem"],
        Effect = "Allow",
        Resource = aws_dynamodb_table.galeria.arn
      },
      {
        Action = ["s3:GetObject"], # Permiso para leer la foto
        Effect = "Allow",
        Resource = "${aws_s3_bucket.imagenes.arn}/*"
      },
      {
        Action = ["rekognition:DetectLabels"], # ¡PERMISO PARA USAR LA IA!
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# 6. El "Gatillo" (Trigger): Que S3 despierte a la Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.procesador_imagenes.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.imagenes.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.imagenes.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.procesador_imagenes.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# 7. Outputs para saber cómo se llama nuestro bucket
output "nombre_del_bucket" {
  value = aws_s3_bucket.imagenes.id
}

# --- 8. NUEVA LAMBDA PARA LA API PUBLICA ---

# Rol de IAM para la API (Solo lectura de DynamoDB)
resource "aws_iam_role" "lambda_api_role" {
  name = "lambda_api_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda_api_policy" {
  name = "lambda_api_dynamo_read"
  role = aws_iam_role.lambda_api_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Effect = "Allow", Resource = "arn:aws:logs:*:*:*" },
      { Action = ["dynamodb:Scan"], Effect = "Allow", Resource = aws_dynamodb_table.galeria.arn }
    ]
  })
}

# La nueva Función Lambda
resource "aws_lambda_function" "api_galeria" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ApiConsultarGaleria"
  role             = aws_iam_role.lambda_api_role.arn
  handler          = "api.handler" # <--- ¡Apunta a nuestro nuevo archivo api.js!
  runtime          = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.galeria.name
    }
  }
}

# --- 9. API GATEWAY (La puerta a Internet) ---
# Usamos HTTP API (v2) porque es más moderna, barata y rápida que REST API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "GaleriaAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api_galeria.invoke_arn
}

# Definimos la ruta: Cuando alguien haga "GET /imagenes", dispara la Lambda
resource "aws_apigatewayv2_route" "get_imagenes" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /imagenes"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Permiso para que API Gateway pueda despertar a la Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_galeria.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# --- 10. EL PREMIO FINAL ---
output "url_de_tu_api" {
  description = "Abre esta URL en tu navegador web"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/imagenes"
}

# --- 11. FRONTEND: S3 WEBSITE HOSTING ---

resource "random_id" "frontend_id" {
  byte_length = 4
}

# Creamos un bucket nuevo para la página web
resource "aws_s3_bucket" "frontend" {
  bucket = "lab-escaparate-web-${random_id.frontend_id.hex}"
  force_destroy = true
}

# Quitamos los bloqueos de seguridad por defecto para que la web sea pública
resource "aws_s3_bucket_public_access_block" "frontend_access" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Le decimos a AWS que cualquiera en internet puede LEER los archivos de este bucket
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.frontend_access]
}

# Configuramos el bucket como servidor web
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

# Subimos automáticamente el archivo HTML
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${path.module}/frontend/index.html"
  content_type = "text/html" # Fundamental para que el navegador lo dibuje y no lo descargue
  etag         = filemd5("${path.module}/frontend/index.html")
}

# --- 12. LA URL DE TU PÁGINA WEB ---
output "url_de_tu_escaparate_web" {
  description = "Abre esta URL para ver tu aplicación completa"
  value       = "http://${aws_s3_bucket_website_configuration.frontend_website.website_endpoint}"
}