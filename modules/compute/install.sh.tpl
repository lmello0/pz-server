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

# --- Mount the save-data EBS volume ---
# The volume attaches asynchronously, shortly after the instance boots,
# so the device may not exist yet when this script runs - wait for it.
DEVICE=/dev/nvme1n1
SAVE_DIR=/home/steam/Zomboid

for i in $(seq 1 30); do
  [ -b "$DEVICE" ] && break
  echo "waiting for $DEVICE to attach ($i/30)..."
  sleep 5
done

if [ ! -b "$DEVICE" ]; then
  echo "ERROR: $DEVICE never appeared; aborting so we don't write saves to ephemeral storage"
  exit 1
fi

# Format ONLY if the volume is blank. `blkid` succeeds if a filesystem
# already exists, which is the case on every rebuild after the first -
# formatting then would destroy every save. This check is what makes the
# volume genuinely persistent across instance replacement.
FRESH_VOLUME=0
if ! blkid "$DEVICE"; then
  echo "no filesystem found on $DEVICE - formatting (first run only)"
  mkfs -t ext4 "$DEVICE"
  FRESH_VOLUME=1
fi

mkdir -p "$SAVE_DIR"
mount "$DEVICE" "$SAVE_DIR"

# Persist the mount across reboots, keyed by UUID (device names can
# change between boots; UUIDs don't).
UUID=$(blkid -s UUID -o value "$DEVICE")
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID $SAVE_DIR ext4 defaults,nofail 0 2" >> /etc/fstab

# Only fix ownership on a freshly-formatted volume. On rebuilds the
# volume is already populated and correctly owned; recursively chowning
# a full 20GB of saves every time would be slow and pointless.
if [ "$FRESH_VOLUME" -eq 1 ]; then
  chown -R steam:steam "$SAVE_DIR"
else
  chown steam:steam "$SAVE_DIR"
fi

INSTALL_DIR=/home/steam/pz-server

# --- Pre-create ~/.steam ---
# SteamCMD's first run tries to symlink ~/.steam/root and ~/.steam/steam
# but the apt package doesn't create ~/.steam, so `ln` errors. Harmless
# on its own, but creating it keeps the logs clean.
sudo -u steam mkdir -p /home/steam/.steam

# --- Install Project Zomboid Dedicated Server (Steam App ID 380870) ---
# Free to download even without owning the game.
#
# SteamCMD's FIRST invocation on a fresh machine reliably fails at the
# app-install step with "Missing configuration" - the apt package is an
# old shim that self-updates on first run, and the app install doesn't
# work until that has settled. The second invocation succeeds. This was
# verified by hand on three separate instances. Retry rather than trying
# to pre-empt whichever piece of first-run state is missing.
STEAM_OK=0
set +e # allow individual attempts to fail without killing the script
for attempt in 1 2 3 4; do
  echo "steamcmd attempt $attempt/4..."
  sudo -H -u steam /usr/games/steamcmd \
    +force_install_dir "$INSTALL_DIR" \
    +login anonymous \
    +app_update 380870 validate \
    +quit
  if [ $? -eq 0 ]; then
    STEAM_OK=1
    echo "steamcmd succeeded on attempt $attempt"
    break
  fi
  echo "attempt $attempt failed, retrying in 10s..."
  sleep 10
done
set -e # back to fail-fast for everything after this

if [ "$STEAM_OK" -ne 1 ]; then
  echo "ERROR: steamcmd failed after 4 attempts"
  exit 1
fi

if [ "$STEAM_OK" -ne 1 ]; then
  echo "ERROR: steamcmd failed after 4 attempts"
  exit 1
fi

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
