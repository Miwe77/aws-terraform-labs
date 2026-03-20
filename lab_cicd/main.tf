provider "aws" {
  region = "us-east-1"
}

# --- 1. LOS 3 BUCKETS ---

resource "random_id" "id" {
  byte_length = 4
}

# Bucket A: Donde subiremos nuestro código (Requiere versionado obligatorio para CodePipeline)
resource "aws_s3_bucket" "fuente" {
  bucket        = "lab-cicd-fuente-${random_id.id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "fuente_ver" {
  bucket = aws_s3_bucket.fuente.id
  versioning_configuration { status = "Enabled" }
}

# Bucket B: Donde CodePipeline guarda sus archivos temporales
resource "aws_s3_bucket" "artefactos" {
  bucket        = "lab-cicd-artefactos-${random_id.id.hex}"
  force_destroy = true
}

# Bucket C: Nuestra página web en Producción
resource "aws_s3_bucket" "produccion" {
  bucket        = "lab-cicd-produccion-${random_id.id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "prod_access" {
  bucket                  = aws_s3_bucket.produccion.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "prod_policy" {
  bucket = aws_s3_bucket.produccion.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "s3:GetObject",
      Effect = "Allow",
      Principal = "*",
      Resource = "${aws_s3_bucket.produccion.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.prod_access]
}

resource "aws_s3_bucket_website_configuration" "prod_website" {
  bucket = aws_s3_bucket.produccion.id
  index_document { suffix = "index.html" }
}

# --- 2. PERMISOS PARA EL ROBOT (IAM) ---

resource "aws_iam_role" "pipeline_role" {
  name = "mi_pipeline_role_${random_id.id.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "pipeline_policy" {
  name = "pipeline_policy"
  role = aws_iam_role.pipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = ["s3:*", "iam:PassRole"]
      Effect = "Allow"
      Resource = "*"
    }]
  })
}

# --- 3. EL PIPELINE (AWS CodePipeline) ---

resource "aws_codepipeline" "mi_pipeline" {
  name     = "Pipeline-Despliegue-Web"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artefactos.bucket
    type     = "S3"
  }

  # ETAPA 1: Obtener el código
  stage {
    name = "Origen"
    action {
      name             = "Descargar_Codigo"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["codigo_fuente"]
      configuration = {
        S3Bucket             = aws_s3_bucket.fuente.bucket
        S3ObjectKey          = "app.zip"
        PollForSourceChanges = "true" # ¡El robot vigila los cambios!
      }
    }
  }

  # ETAPA 2: Desplegar en Producción
  stage {
    name = "Despliegue"
    action {
      name            = "Copiar_a_Produccion"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["codigo_fuente"]
      version         = "1"
      configuration = {
        BucketName = aws_s3_bucket.produccion.bucket
        Extract    = "true" # Descomprime el .zip automáticamente
      }
    }
  }
}

# --- 4. OUTPUTS ---
output "bucket_fuente_para_subir_zip" { value = aws_s3_bucket.fuente.id }
output "url_web_produccion" { value = "http://${aws_s3_bucket_website_configuration.prod_website.website_endpoint}" }