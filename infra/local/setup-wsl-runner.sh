#!/usr/bin/env bash
# Turn a WSL Ubuntu (or any Linux box with Docker) into the deploy target:
# app checkout in /opt/nanhr + GitHub Actions self-hosted runner (label: proxmox).
# Run as root:  setup-wsl-runner.sh <runner-registration-token>
set -euo pipefail

TOKEN="${1:?usage: setup-wsl-runner.sh <runner-registration-token>}"
REPO_URL=https://github.com/sangdikalin168/nanhr-devops
APP_DIR=/opt/nanhr
RUNNER_DIR=/home/deploy/runner
# GitHub rejects old runners, so always fetch the latest release.
RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)"
RUNNER_VERSION="$(sed -nE 's/.*"tag_name": *"v([^"]+)".*/\1/p' <<<"$RELEASE_JSON")"

id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy

# Fresh git checkout, keeping an existing deploy/.env.
if [[ ! -d "$APP_DIR/.git" ]]; then
  [[ -f "$APP_DIR/deploy/.env" ]] && cp "$APP_DIR/deploy/.env" /tmp/nanhr.env
  rm -rf "$APP_DIR"
  git clone -q "$REPO_URL" "$APP_DIR"
  if [[ -f /tmp/nanhr.env ]]; then mv /tmp/nanhr.env "$APP_DIR/deploy/.env"
  else cp "$APP_DIR/deploy/.env.example" "$APP_DIR/deploy/.env"; fi
fi
chown -R deploy:deploy "$APP_DIR"

if [[ ! -f "$RUNNER_DIR/.runner" ]]; then
  sudo -u deploy bash -c "
    mkdir -p '$RUNNER_DIR' && cd '$RUNNER_DIR'
    curl -fsSL -o r.tgz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
    tar xzf r.tgz && rm r.tgz
    ./config.sh --unattended --replace --url '$REPO_URL' --token '$TOKEN' --labels proxmox --name \"\$(hostname)-wsl\"
  "
  cd "$RUNNER_DIR" && ./svc.sh install deploy
fi
cd "$RUNNER_DIR" && ./svc.sh start
./svc.sh status | grep -E 'Active:' || true
echo "Runner ready. Push to main (or re-run the CD workflow) to deploy here."
