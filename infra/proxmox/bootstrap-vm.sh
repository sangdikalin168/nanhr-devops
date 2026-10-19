#!/usr/bin/env bash
# Run inside the new VM as root: Docker, AWS CLI, backup cron, GitHub Actions runner.
# Needs: RUNNER_URL (https://github.com/<user>/<repo>) and RUNNER_TOKEN (Settings -> Actions -> Runners -> New).
set -euo pipefail

: "${RUNNER_URL:?set RUNNER_URL}"; : "${RUNNER_TOKEN:?set RUNNER_TOKEN}"
APP_DIR=/opt/nanhr
# GitHub rejects old runners, so always fetch the latest release.
RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)"
RUNNER_VERSION="$(sed -nE 's/.*"tag_name": *"v([^"]+)".*/\1/p' <<<"$RELEASE_JSON")"

apt-get update
apt-get install -y ca-certificates curl git unzip qemu-guest-agent
systemctl enable --now qemu-guest-agent

# Docker Engine + Compose plugin
curl -fsSL https://get.docker.com | sh
useradd --create-home --shell /bin/bash deploy 2>/dev/null || true
usermod -aG docker deploy

# AWS CLI v2 for S3 backups
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/aws.zip
unzip -q -o /tmp/aws.zip -d /tmp && /tmp/aws/install --update

# App checkout
git clone "$RUNNER_URL" "$APP_DIR" 2>/dev/null || git -C "$APP_DIR" pull
cp -n "$APP_DIR/deploy/.env.example" "$APP_DIR/deploy/.env"
chown -R deploy:deploy "$APP_DIR"
chmod +x "$APP_DIR"/scripts/*.sh

# Nightly backup at 02:00
echo "0 2 * * * deploy $APP_DIR/scripts/backup-postgres.sh >> /var/log/nanhr-backup.log 2>&1" > /etc/cron.d/nanhr-backup

# Self-hosted GitHub Actions runner (label: proxmox)
sudo -u deploy bash -c "
  mkdir -p ~/runner && cd ~/runner
  curl -fsSL -o r.tgz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
  tar xzf r.tgz && rm r.tgz
  ./config.sh --unattended --url '$RUNNER_URL' --token '$RUNNER_TOKEN' --labels proxmox --name \$(hostname)
"
cd /home/deploy/runner && ./svc.sh install deploy && ./svc.sh start

echo "Done. Edit $APP_DIR/deploy/.env, then push to main to deploy."
