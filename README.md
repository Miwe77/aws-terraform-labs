# ☁️ AWS Cloud & DevOps Portfolio

¡Bienvenido a mi portafolio de Arquitectura Cloud y DevOps! 🚀 

Este repositorio contiene una colección de laboratorios prácticos desplegados 100% como **Infraestructura como Código (IaC)** utilizando **Terraform**. El objetivo de estos proyectos es demostrar la capacidad de diseñar, desplegar y automatizar arquitecturas modernas, escalables y seguras en Amazon Web Services (AWS).

## 🛠️ Stack Tecnológico

* **Cloud Provider:** AWS (Amazon Web Services)
* **Infrastructure as Code (IaC):** Terraform
* **Contenedores y Orquestación:** Docker, Amazon ECS (Fargate), Amazon EKS (Kubernetes)
* **Serverless & Event-Driven:** AWS Lambda, API Gateway, DynamoDB, S3 Events
* **CI/CD & Automatización:** AWS CodePipeline
* **Inteligencia Artificial:** Amazon Rekognition
* **Lenguajes:** Python (Flask), Node.js, HTML/CSS/JS
* **Observabilidad:** Prometheus, Grafana, Helm

---

## 🏗️ Arquitecturas Desplegadas

### 1. ☸️ Kubernetes: Amazon EKS & Observabilidad (`lab_eks`)
Despliegue de un clúster gestionado de Kubernetes en AWS preparado para producción.
* Aprovisionamiento del clúster EKS y los *Worker Nodes* con Terraform.
* Gestión de paquetes de Kubernetes mediante **Helm**.
* Implementación de un stack completo de observabilidad utilizando **Prometheus** (recolección de métricas) y **Grafana** (dashboards de visualización).

### 2. ⚡ Serverless & Inteligencia Artificial (`lab_serverless`)
Arquitectura orientada a eventos (Event-Driven) que procesa imágenes automáticamente utilizando IA.
* **Flujo:** Un usuario sube una imagen a un bucket S3 privado, lo que dispara un evento que despierta una función **AWS Lambda** (Node.js).
* **Procesamiento AI:** La Lambda envía la imagen a **Amazon Rekognition** para identificar los elementos de la foto (etiquetas/tags).
* **Almacenamiento:** Los metadatos y etiquetas generados por la IA se guardan en una base de datos NoSQL ultrarrápida (**DynamoDB**).
* **Exposición (API):** Una segunda Lambda sirve los datos de DynamoDB al exterior de forma segura a través de **API Gateway**.
* **Frontend:** Una Single Page Application (SPA) estática alojada en S3 que consume la API y muestra la galería inteligente.

### 3. 🐳 Contenedores Serverless: ECS Fargate (`lab_ecs`)
Despliegue de una aplicación clásica de 3 capas (Frontend, Backend, Base de Datos) sin administrar servidores subyacentes.
* Creación de repositorios privados de imágenes Docker en **Amazon ECR**.
* Contenerización de una API (Backend) y una Web (Frontend) escritas en Python (Flask).
* Uso del patrón *Sidecar* en **Amazon ECS con Fargate**, agrupando los contenedores de Frontend, Backend y PostgreSQL en una misma Tarea (Task) para comunicación segura y privada por `localhost`.
* Configuración de Grupos de Seguridad (Security Groups) para exponer únicamente el puerto HTTP al exterior.

### 4. 🔄 CI/CD: Pipeline de Despliegue Continuo (`lab_cicd`)
Automatización completa del ciclo de vida de desarrollo de software para integraciones y despliegues sin tiempo de inactividad (Zero Downtime).
* Creación de buckets S3 con versionado para código fuente, artefactos temporales y entorno de producción.
* Implementación de **AWS CodePipeline** para vigilar los cambios en el repositorio.
* Despliegue automatizado de nuevas versiones de la aplicación estática al detectar subidas de archivos `.zip`, garantizando entregas rápidas y seguras.

---

## 🚀 Cómo utilizar este repositorio

Cada carpeta contiene sus respectivos archivos de configuración y código fuente. Para replicar cualquiera de estas arquitecturas:

1. Clona el repositorio: `git clone https://github.com/TU_USUARIO/TU_REPO.git`
2. Navega al directorio del laboratorio deseado (ej. `cd lab_serverless`).
3. Inicializa Terraform: `terraform init`
4. Revisa los recursos a crear: `terraform plan`
5. Despliega la infraestructura: `terraform apply -auto-approve`

> **⚠️ Advertencia de Costes:** Estos laboratorios levantan recursos reales en AWS. Para evitar cargos inesperados en tu factura, recuerda ejecutar siempre `terraform destroy -auto-approve` al finalizar tus pruebas.
