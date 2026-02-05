packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "image_name" {
  type    = string
  default = "custom-nginx"
}

variable "image_tag" {
  type    = string
  default = "v1"
}

source "docker" "nginx" {
  image  = "nginx:alpine"
  commit = true
}

build {
  sources = ["source.docker.nginx"]

  provisioner "shell" {
    inline = [
      "mkdir -p /usr/share/nginx/html"
    ]
  }

  provisioner "file" {
    source      = "../index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  post-processor "docker-tag" {
    repository = var.image_name
    tags       = [var.image_tag]
  }
}
