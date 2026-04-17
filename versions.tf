terraform {
  required_version = ">= 1.5.0"
  # REMOVE IF YOU WANT TO MANAGE STATE LOCALLY
  # backend "s3" {
  #   bucket         = "<YOUR_BUCKET_NAME>"
  #   key            = "<YOUR_OBJECT_KEY>"
  #   region         = "<YOUR_AWS_REGION>"
  #   use_lockfile   = true
  #   dynamodb_table = "<YOUR_DYNAMODB_TABLE>"
  #   encrypt        = true
  # }
  
  # Estado local: ficheiro no diretório do projeto (equivalente ao comportamento por defeito sem bloco backend).
  # Opcional: path relativo ou absoluto. Para partilhar estado remoto (S3, etc.), substituir por outro backend e correr terraform init -migrate-state.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc03"
    }
  }
}