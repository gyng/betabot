job "betabot" {
  datacenters = ["ap-southeast-1a", "ap-southeast-1b"]

  group "neotype" {
    count = 1

    template {
      data = "{{ key \"example/betabot/slack/bot_settings.json\" }}"
      destination = "lib/settings/bot_settings.json"
    }

    template {
      data = "{{ key \"example/betabot/slack/adapters/slack.json\" }}"
      destination = "lib/settings/adapters/slack.json"
    }

    task "slack" {
      driver = "docker"

      config {
        image = "gyng/betabot"
        command = "bundle"
        args = [
            "exec",
            "ruby",
            "start_bot.rb"
        ]

        port_map = {
          http = 80
        }

        volumes = [
          "lib/databases:/app/lib/databases",
          "lib/public:/app/lib/public",
          "lib/settings:/app/lib/settings"
        ]
      }

      service {
        name = "${JOB}-slack-web"
        port = "http"

        check {
          name     = "betabot-web-check"
          type     = "tcp"
          interval = "60s"
          timeout  = "5s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:betabot.my.domain.name"
        ]
      }

      resources {
        memory = 500

        network {
          mbits = 10
          port "http" {}
        }
      }
    }
  }
}
