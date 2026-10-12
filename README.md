# Corosync QNetd for Home Assistant OS

A Home Assistant OS local app that runs `corosync-qnetd`, so a Home Assistant instance can act as the QDevice (third quorum vote) for a two-node Proxmox VE cluster.

With only two nodes, a Proxmox cluster loses quorum as soon as one node goes down, and HA won't fail over. The QDevice adds an external tie-breaker vote so the surviving node stays quorate.

## How it works

- The app runs `corosync-qnetd` in a Debian container and listens on **TCP 5403**.
- Each Proxmox node runs `corosync-qdevice`, which connects to qnetd over TLS.
- `pvecm qdevice setup` needs **root SSH** into the qnetd host once, to create and sign the certificates. The app includes an sshd for that, which you turn off after setup.
- The certificate database is stored in `/data`, so it survives app updates and rebuilds.

## Requirements

- Home Assistant OS 2026.2 or later (apps, formerly add-ons)
- An `amd64` host (add `aarch64` to `arch` in `config.yaml` for a Raspberry Pi)
- A two-node Proxmox VE cluster
- A static IP or DHCP reservation for the Home Assistant instance
- TCP 5403 reachable from every Proxmox node

## Installation

### 1. Install the app on Home Assistant

1. Copy the `qnetd/` folder into `local_apps/` on the Home Assistant instance (for example via the Samba or SSH app).
2. Make sure `run.sh` has **LF** line endings. CRLF makes the container fail with "no such file or directory".
3. Go to **Settings → Apps → App store → ⋮ → Check for updates**.
4. Install **Corosync QNetd** from the local apps section.
5. In the app's configuration, set `root_password` (needed for the setup step only).
6. Start the app.

Published ports:

| Container | Host | Purpose              |
| --------- | ---- | -------------------- |
| 5403/tcp  | 5403 | qnetd, always needed |
| 22/tcp    | 2222 | SSH, setup only      |

Port 22 inside the container doesn't conflict with the Home Assistant SSH app; only the host ports have to be unique.

### 2. Install the QDevice client on every Proxmox node

```bash
apt update && apt install -y corosync-qdevice
```

Skipping this on any node makes setup fail with `corosync-qdevice-net-certutil: command not found`.

### 3. Point SSH at port 2222

On the node you'll run the setup from, add to `/root/.ssh/config` (replace `IP_ADDRESS` with the IP of the Home-Assistant intance):

```
Host IP_ADDRESS
    HostName IP_ADDRESS
    Port 2222
    User root
```

Optionally, test if the config works:

```bash
# Should print /usr/sbin/corosync-qnetd
ssh IP_ADDRESS 'which corosync-qnetd'
```

### 4. Run the setup

```bash
pvecm qdevice setup IP_ADDRESS
```

## Verification

The Proxmox web UI doesn't show the QDevice; use `pvecm status` or `systemctl status corosync-qdevice` on a node.

## Lock down after setup

SSH is only used during setup. Afterwards:

1. Clear `root_password` in the app configuration (sshd won't start without it).
2. Restart the app and confirm `pvecm status` still shows 3 votes.

## Re-running setup

When adding or removing a cluster node, Proxmox expects you to:

1. `pvecm qdevice remove`
2. Change the cluster membership
3. Re-enable the SSH port and password, then `pvecm qdevice setup <ip>` again

## Caveats

- Only useful for clusters with an even number of nodes (typically 2).
- If the Home Assistant instance is down at the same time as one Proxmox node, the remaining node loses quorum.
- Home Assistant OS updates briefly restart apps. That only matters if a Proxmox node is down at that moment.
