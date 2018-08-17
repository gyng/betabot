// 0. Add Slack token to vault at `secret/betabot/slack` with the key `api_token`
//
// 1. Login to vault on deploying machine
//
//    vault login --method ldap --address https://vault.example.com username=AzureDiamond
//
// 2. Submit the job with vault credentials
//
//    VAULT_TOKEN=$(cat ~/.vault-token) nomad run --address https://nomad.example.com extra/betabot.slack.nomad

job "betabot" {
  datacenters = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]

  // Add betabot_app policy to access Slack token on Vault
  // User running this must have the betabot_app policy
  vault {
    policies = ["betabot_app"]
    change_mode = "restart"
    env = false
  }

  group "neotype" {
    count = 1

    ephemeral_disk {
      migrate = true
      size    = "300"
      sticky  = true
    }

    task "slack" {
      driver = "docker"

      template {
        data = <<EOF
{
  "short_trigger": "~",

  "adapters": {
    "dir": "adapters",
    "load_mode": "blacklist",
    "autostart": ["slack"],
    "whitelist": [],
    "blacklist": ["dummy"]
  },

  "plugins": {
    "dir": "plugins",
    "load_mode": "blacklist",
    "whitelist": [],
    "blacklist": ["dummy", "script"]
  },

  "external_plugins": {
    "dir": "external_plugins",
    "load_mode": "blacklist",
    "whitelist": [],
    "blacklist": []
  },

  "databases": {
    "shared_db": true
  },

  "webserver": {
    "enabled": true,
    "link_url": "http://localhost:80",
    "host": "0.0.0.0",
    "port": "80"
  }
}
EOF
        destination = "alloc/lib/settings/bot_settings.user.json"
      }

      template {
        data = <<EOF
{{- with secret "secret/betabot/slack" -}}{{ .Data | toJSON }}{{- end -}}
EOF
        destination = "secrets/slack.json"
      }

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
          "alloc/lib/databases:/app/lib/databases",
          "alloc/lib/public:/app/lib/public",
          "alloc/lib/settings:/app/lib/settings",
          "alloc/lib/external_plugins:/app/lib/external_plugins",
          "secrets/slack.json:/app/lib/settings/adapters/slack.json:ro"
        ]
      }

      service {
        name = "${JOB}-slack-web"
        port = "http"

        check {
          name     = "betabot-web-check"
          path     = "/"
          type     = "tcp"
          interval = "60s"
          timeout  = "5s"
        }

        // tags = [
        //   "traefik.enable=true",
        //   "traefik.frontend.rule=Host:betabot.my.domain.name"
        // ]
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
