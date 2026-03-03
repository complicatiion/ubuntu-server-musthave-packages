
# ubuntu-server-musthave-packages installation script

Interactive Ubuntu Server bootstrap script for installing common admin/monitoring/network tools on Ubuntu Server 24.04+ (works on newer LTS as well).

## What it does

- Shows a structured overview of available components (with short descriptions).
- Prompts you **per component** (`y/N`) and installs only what you approve.
- Enables/starts a few relevant services (best-effort):
  - `ssh`, `cockpit.socket`, `xrdp`, `avahi-daemon`, `ntp`, `fail2ban`
- Offers an **optional UFW configuration step** at the end (recommended to avoid lockouts).

## Components you can install

**Web UI / Admin**
- Cockpit (+ cockpit-podman)
- Webmin (via official repository setup script)

**Networking & Remote Access**
- openssh-server, curl/wget, ufw, net-tools, traceroute, iperf3, iperf (legacy), mosh, xrdp, avahi-daemon + avahi-utils

**Storage / Filesystems**
- cifs-utils

**Time**
- ntp

**Monitoring**
- htop, iotop, nmon, ncdu, glances, logwatch

**Security**
- fail2ban

**Testing**
- stress

**Admin & Utilities**
- vim, jq

**Development**
- build-essential, python3

## Requirements / Notes

- Must be run with **root privileges** (the script auto-reexecs via `sudo` if needed).
- Uses `apt-get` with `DEBIAN_FRONTEND=noninteractive`.
- Enables Ubuntu **universe** repository when needed.
- **XRDP**: installing `xrdp` alone is not a full remote-desktop experience; you usually need a desktop environment/session configured.
- **Logwatch**: daily emails require an MTA (mail setup is not included).
- **Webmin**: installs through the official Webmin repo script (downloads a script from GitHub). Only install if that is acceptable in your environment.
- **UFW**: if you enable it, always allow SSH first (the script asks).

## Usage

```bash
chmod +x ubuntu-server-musthave-packages
./ubuntu-server-musthave-packages


## After install (ports to consider)

If you enable UFW or need to adjust network policies:

* SSH: `22/tcp`
* Cockpit: `9090/tcp`
* Webmin: `10000/tcp`
* XRDP: `3389/tcp`
* mosh: `60000-61000/udp`
* iperf3 server: `5201/tcp`
* NTP: `123/udp`

