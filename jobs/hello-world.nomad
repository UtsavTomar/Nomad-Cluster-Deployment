job "hello-world" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "hello-world"
      port = "http"

      tags = [
        "urlprefix-/",
        "traefik.enable=true"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "hello-world" {
      driver = "docker"

      config {
        image = "587688724297.dkr.ecr.us-west-2.amazonaws.com/nomad-hello-world:latest"
        ports = ["http"]
      }

      env {
        NODE_ENV = "production"
        PORT     = "3000"
        HOST     = "0.0.0.0"
      }

      resources {
        cpu    = 50
        memory = 64
      }

      restart {
        attempts = 3
        interval = "30m"
        delay    = "15s"
        mode     = "fail"
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    reschedule {
      attempts       = 3
      interval       = "5m"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "1h"
      unlimited      = false
    }
  }
}
