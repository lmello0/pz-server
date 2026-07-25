#!/bin/bash
#
# Runs ONCE, by Packer, against a temporary instance. Bakes in everything
# slow and static about the Project Zomboid install: SteamCMD, the game
# download itself, and the JVM heap fix.
#
# Deliberately excludes anything that varies per deployment - save data,
# server/admin/RCON passwords, the systemd unit. Those stay in Terraform's
# boot script (modules/compute/install.sh.tpl), which checks for the
# marker file this script writes at the very end and skips straight past
# everything here when it finds it.
#
# Runs as the "ubuntu" user over SSH (Packer's default), hence sudo
# everywhere - unlike install.sh.tpl, which cloud-init runs as root.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

INSTALL_DIR=/home/steam/pz-server

# --- SteamCMD is a 32-bit binary, so enable multiverse + i386 first ---
sudo add-apt-repository -y multiverse
sudo dpkg --add-architecture i386
sudo apt-get update -y

# --- Pre-accept Steam's EULA ---
# Without this, `apt-get install steamcmd` hangs forever waiting for a
# terminal prompt that will never come during an automated build.
echo steam steam/question select "I AGREE" | sudo debconf-set-selections
echo steam steam/license note ''            | sudo debconf-set-selections
sudo apt-get install -y steamcmd

# --- Dedicated, unprivileged user to run the game as ---
# Keeps any exploit in the game code contained to this one account,
# not the whole machine.
id -u steam &>/dev/null || sudo useradd -m -s /bin/bash steam

# --- Pre-create ~/.steam ---
# SteamCMD's first run tries to symlink ~/.steam/root and ~/.steam/steam
# but the apt package doesn't create ~/.steam, so `ln` errors. Harmless
# on its own, but this keeps the build log clean.
sudo -u steam mkdir -p /home/steam/.steam

# --- Install Project Zomboid Dedicated Server (Steam App ID 380870) ---
# Free to download even without owning the game.
#
# SteamCMD's FIRST invocation on a fresh machine reliably fails at the
# app-install step with "Missing configuration" - the apt package is an
# old shim that self-updates on first run, and the app install doesn't
# work until that has settled. The second invocation succeeds. Verified
# by hand across several builds - retry rather than guess at the cause.
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

# Depot files sometimes lose their executable bit on extraction.
sudo chmod +x "$INSTALL_DIR/start-server.sh" "$INSTALL_DIR/ProjectZomboid64" || true

# NOTE: the JVM heap cap is deliberately NOT applied here. It depends on
# the instance size, which Packer has no knowledge of - baking a fixed
# value in would silently override whatever jvm_heap_mb is set to in
# Terraform. install.sh.tpl applies it at boot instead, on every deploy,
# baked AMI or not.

sudo chown -R steam:steam "$INSTALL_DIR"

# --- Start wrapper with a control pipe ---
# Lets the systemd unit (written later, at deploy time, since it needs
# the per-deployment admin password) shut the server down gracefully by
# writing 'quit' into a FIFO instead of sending SIGTERM, which would skip
# PZ's save-on-exit entirely. No secrets in this script, so it's safe
# to bake.
sudo tee "$INSTALL_DIR/run-server.sh" > /dev/null <<'WRAPPER'
#!/bin/bash
PIPE=/home/steam/pz-server/control.pipe
INSTALL_DIR=/home/steam/pz-server

rm -f "$PIPE"
mkfifo "$PIPE"

# Hold the pipe open for writing so it never sees EOF, otherwise the
# server would read EOF immediately and exit.
sleep infinity > "$PIPE" &
HOLDER=$!

# shellcheck disable=SC2064
trap "kill $HOLDER 2>/dev/null; rm -f $PIPE" EXIT

"$INSTALL_DIR/start-server.sh" "$@" < "$PIPE"
WRAPPER

sudo chmod +x "$INSTALL_DIR/run-server.sh"
sudo chown steam:steam "$INSTALL_DIR/run-server.sh"

# --- Marker file ---
# install.sh.tpl checks for this at boot to know it can skip everything
# above and go straight to mounting the save volume and starting the
# service.
sudo touch /etc/pz-server-baked

echo "bake complete"
