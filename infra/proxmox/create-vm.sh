#!/usr/bin/env bash
# Run on the Proxmox host: create an Ubuntu 24.04 cloud-init VM for the Docker stack.
# Usage: ./create-vm.sh <vmid> <name> [storage] [bridge]
set -euo pipefail

VMID="${1:?vmid}"; NAME="${2:?name}"
STORAGE="${3:-local-lvm}"; BRIDGE="${4:-vmbr0}"
IMG=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519.pub}"

[[ -f "$IMG" ]] || wget -O "$IMG" https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

qm create "$VMID" --name "$NAME" --memory 4096 --cores 2 --cpu host \
  --net0 virtio,bridge="$BRIDGE" --scsihw virtio-scsi-single --agent enabled=1 \
  --ostype l26 --onboot 1
qm set "$VMID" --scsi0 "$STORAGE":0,import-from="$IMG",discard=on,ssd=1
qm resize "$VMID" scsi0 40G
qm set "$VMID" --ide2 "$STORAGE":cloudinit --boot order=scsi0 \
  --ipconfig0 ip=dhcp --ciuser ubuntu --sshkeys "$SSH_KEY"
qm start "$VMID"

echo "VM $VMID ($NAME) started. Take a snapshot after bootstrap: qm snapshot $VMID baseline"
