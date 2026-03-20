provider "aws" {
  region = "us-east-1"
}

# 1. Repositorio para el Backend (Python API)
resource "aws_ecr_repository" "backend" {
  name                 = "lab-ecs-backend"
  force_delete         = true # Fundamental para poder hacer el destroy limpio luego
  image_tag_mutability = "MUTABLE"
}

# 2. Repositorio para el Frontend (Python Web)
resource "aws_ecr_repository" "frontend" {
  name                 = "lab-ecs-frontend"
  force_delete         = true
  image_tag_mutability = "MUTABLE"
}

# 3. Outputs que necesitaremos para subir las imágenes de Docker
output "ecr_backend_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.frontend.repository_url
}

# --- FASE 3: ECS Y FARGATE ---

# 1. Recuperamos la red por defecto de tu cuenta (VPC)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 2. Grupo de Seguridad (El Firewall)
resource "aws_security_group" "ecs_sg" {
  name        = "lab-ecs-sg"
  description = "Permitir trafico HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Abierto a todo internet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Permite a los contenedores salir a internet (para descargar la BD)
  }
}

# 3. El Clúster de ECS (La agrupación lógica)
resource "aws_ecs_cluster" "mi_cluster" {
  name = "lab-cluster"
}

# 4. El Rol de Ejecución (Para que ECS pueda descargar tus imágenes de ECR)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role_lab"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 5. La Definición de la Tarea (Nuestros 3 contenedores juntos)
resource "aws_ecs_task_definition" "mi_app" {
  family                   = "app-3-capas"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024" # 1 vCPU
  memory                   = "2048" # 2 GB de RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  # Aquí definimos los 3 contenedores en JSON
  container_definitions = jsonencode([
    {
      name      = "base-de-datos"
      image     = "postgres:13"
      essential = true
      portMappings = [{ containerPort = 5432 }]
      environment = [
        { name = "POSTGRES_DB", value = "postgres" },
        { name = "POSTGRES_USER", value = "postgres" },
        { name = "POSTGRES_PASSWORD", value = "password123" }
      ]
    },
    {
      name      = "backend-api"
      image     = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 5000 }]
      environment = [
        { name = "DB_HOST", value = "localhost" },
        { name = "DB_NAME", value = "postgres" },
        { name = "DB_USER", value = "postgres" },
        { name = "DB_PASSWORD", value = "password123" }
      ]
    },
    {
      name      = "frontend-web"
      image     = "${aws_ecr_repository.frontend.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 80 }]
      environment = [
        { name = "BACKEND_URL", value = "http://localhost:5000" }
      ]
    }
  ])
}

# 6. El Servicio (Le dice a ECS que mantenga la tarea siempre encendida)
resource "aws_ecs_service" "mi_servicio" {
  name            = "servicio-app-3-capas"
  cluster         = aws_ecs_cluster.mi_cluster.id
  task_definition = aws_ecs_task_definition.mi_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true # Le asigna una IP pública para que podamos verla
  }
}