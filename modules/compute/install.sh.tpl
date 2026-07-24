#!/bin/bash
# Runs once as root via cloud-init on the instance's first boot.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- SteamCMD is a 32-bit binary, so enable multiverse + i386 first ---
add-apt-repository -y multiverse
dpkg --add-architecture i386
apt-get update -y

# --- Pre-accept Steam's EULA ---
# Without this, `apt-get install steamcmd` hangs forever waiting for a
# terminal prompt that will never come during an automated boot.
echo steam steam/question select "I AGREE" | debconf-set-selections
echo steam steam/license note ''            | debconf-set-selections
apt-get install -y steamcmd

# --- Dedicated, unprivileged user to run the game as ---
# Keeps any exploit in the game code contained to this one account,
# not the whole machine.
id -u steam &>/dev/null || useradd -m -s /bin/bash steam

INSTALL_DIR=/home/steam/pz-server

# --- Bootstrap SteamCMD once by itself first ---
# `sudo -u steam` alone does NOT reset $HOME to the steam user's home
# directory - it inherits root's ($HOME=/root), which the steam user
# can't write to. SteamCMD silently writes its own package/depot cache
# under $HOME, so without -H (which forces HOME to match the target
# user) it ends up with a broken cache and app_update fails with
# "Missing configuration" even though login succeeded. -H fixes that.
sudo -H -u steam /usr/games/steamcmd +quit

# --- Install Project Zomboid Dedicated Server (Steam App ID 380870) ---
# Free to download even without owning the game.
sudo -H -u steam /usr/games/steamcmd \
  +force_install_dir "$INSTALL_DIR" \
  +login anonymous \
  +app_update 380870 validate \
  +quit

# Depot files sometimes lose their executable bit on extraction.
chmod +x "$INSTALL_DIR/start-server.sh" "$INSTALL_DIR/ProjectZomboid64" || true

# --- Cap the JVM heap ---
# The shipped config (ProjectZomboid64.json) defaults to requesting a
# 16GB heap. Our instance only has 8GB of RAM total, so left as-is the
# server crashes on boot with an out-of-memory error. 5GB leaves headroom
# for the OS and Java's own overhead.
sed -i 's/-Xmx[0-9]*g/-Xmx5g/' "$INSTALL_DIR/ProjectZomboid64.json"
sed -i 's/-Xms[0-9]*g/-Xms2g/' "$INSTALL_DIR/ProjectZomboid64.json"

chown -R steam:steam "$INSTALL_DIR"

# --- systemd service ---
# Starts the server on boot and restarts it automatically if it crashes.
# Server name/password/admin config gets refined in a later step - this
# gets a vanilla server running end to end first.
cat > /etc/systemd/system/zomboid.service <<EOF
[Unit]
Description=Project Zomboid Dedicated Server
After=network.target

[Service]
User=steam
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start-server.sh -servername servertest -adminpassword "${admin_password}"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zomboid.service
systemctl start zomboid.service
