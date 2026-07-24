#!/usr/bin/env bash
#
# Management wrapper for the Project Zomboid Terraform stack.
#
#   ./pz.sh setup    - interactive first-time configuration (writes terraform.tfvars)
#   ./pz.sh start    - allocate EIP + DNS, boot the instance
#   ./pz.sh stop     - save the world, shut down, release EIP to cut costs
#   ./pz.sh status   - what's running and what it's costing
#   ./pz.sh ssh      - connect to the server
#   ./pz.sh logs     - follow the game server log
#
# Works in git-bash / WSL on Windows, and natively on Linux/macOS.

set -uo pipefail

cd "$(dirname "$0")"

TFVARS="terraform.tfvars"

# --- Colours (disabled when not a terminal, e.g. piped to a file) ---
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[0;33m'; BLU=$'\033[0;34m'; RST=$'\033[0m'
else
  RED=''; GRN=''; YLW=''; BLU=''; RST=''
fi

info()  { echo "${BLU}==>${RST} $*"; }
ok()    { echo "${GRN}OK${RST}  $*"; }
warn()  { echo "${YLW}!!${RST}  $*"; }
err()   { echo "${RED}ERR${RST} $*" >&2; }

die() { err "$*"; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed or not on PATH"
}

# Read a single output value; empty string if it doesn't exist yet.
tf_out() {
  terraform output -raw "$1" 2>/dev/null || true
}

# Read a variable's value out of terraform.tfvars.
tfvar() {
  [ -f "$TFVARS" ] || return
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$TFVARS" 2>/dev/null \
    | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^"//; s/"[[:space:]]*$//'
}

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------
cmd_setup() {
  need terraform

  if [ -f "$TFVARS" ]; then
    warn "$TFVARS already exists."
    read -r -p "Overwrite it? [y/N] " reply
    case "$reply" in
      [yY]*) ;;
      *) info "Keeping existing file. Nothing changed."; return 0 ;;
    esac
    cp "$TFVARS" "$TFVARS.bak"
    info "Backed up existing config to $TFVARS.bak"
  fi

  echo
  info "Interactive setup - press Enter to accept the [default] where shown."
  echo

  # --- admin IP ---
  echo "${BLU}Your public IP${RST} locks down SSH and the RCON admin port."
  local detected=""
  if command -v curl >/dev/null 2>&1; then
    detected=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || true)
  fi
  if [ -n "$detected" ]; then
    echo "  Detected: $detected"
    read -r -p "  Use this? [Y/n] " reply
    case "$reply" in
      [nN]*) read -r -p "  Enter your IPv4 address: " detected ;;
    esac
  else
    warn "Could not auto-detect (are you on IPv6-only?)."
    read -r -p "  Enter your IPv4 address: " detected
  fi
  [ -n "$detected" ] || die "An admin IP is required."
  # Accept either a bare IP or one already in CIDR form.
  case "$detected" in
    */*) local admin_ip="$detected" ;;
    *)   local admin_ip="$detected/32" ;;
  esac
  echo

  # --- SSH key ---
  echo "${BLU}SSH key${RST} - the PUBLIC half gets uploaded to AWS."
  local default_key="$HOME/.ssh/pz-server-key.pub"
  read -r -p "  Path to public key [$default_key]: " key_path
  key_path="${key_path:-$default_key}"
  if [ ! -f "$key_path" ]; then
    warn "No key at $key_path"
    read -r -p "  Generate one now? [Y/n] " reply
    case "$reply" in
      [nN]*) die "A key pair is required. Create one with: ssh-keygen -t ed25519 -f ${key_path%.pub}" ;;
      *)
        need ssh-keygen
        mkdir -p "$(dirname "$key_path")"
        ssh-keygen -t ed25519 -f "${key_path%.pub}" -N "" -C "pz-server" \
          || die "ssh-keygen failed"
        ok "Created ${key_path%.pub} and $key_path"
        ;;
    esac
  fi
  echo

  # --- budget ---
  echo "${BLU}Budget alerts${RST} - AWS emails you, it does not cap spending."
  read -r -p "  Alert email: " alert_email
  [ -n "$alert_email" ] || die "An email address is required for budget alerts."
  read -r -p "  Monthly threshold in USD [20]: " budget
  budget="${budget:-20}"
  echo

  # --- cloudflare ---
  echo "${BLU}Cloudflare DNS${RST} (optional - gives friends a hostname instead of an IP)."
  read -r -p "  Configure Cloudflare? [y/N] " reply
  local cf_block=""
  case "$reply" in
    [yY]*)
      echo "  Zone ID: domain Overview page, right sidebar."
      read -r -p "  Zone ID: " cf_zone
      echo "  Token: My Profile > API Tokens > 'Edit zone DNS' template."
      read -r -s -p "  API token (hidden): " cf_token; echo
      read -r -p "  Subdomain [pz]: " cf_name
      cf_name="${cf_name:-pz}"
      [ -n "$cf_zone" ] && [ -n "$cf_token" ] || die "Zone ID and token are both required."
      cf_block=$(cat <<EOF

# --- Cloudflare ---
cloudflare_zone_id   = "$cf_zone"
cloudflare_api_token = "$cf_token"
dns_record_name      = "$cf_name"
EOF
)
      ;;
    *)
      warn "Skipping Cloudflare. You'll connect by raw IP."
      warn "The dns module still needs values - add them later or remove the module from main.tf."
      ;;
  esac

  # --- write it out ---
  cat > "$TFVARS" <<EOF
# pz-server/terraform.tfvars
# Generated by ./pz.sh setup - contains secrets, never commit this file.

# --- Access ---
admin_ip            = "$admin_ip"
ssh_public_key_path = "$key_path"

# --- Cost guardrail ---
alert_email        = "$alert_email"
monthly_budget_usd = "$budget"

# --- Static IP ---
# false releases the Elastic IP while the server is stopped, which avoids
# the hourly charge AWS applies to unattached/idle EIPs. ./pz.sh handles
# flipping this automatically.
use_elastic_ip = true
$cf_block
EOF

  chmod 600 "$TFVARS" 2>/dev/null || true
  ok "Wrote $TFVARS"
  echo
  info "Next: terraform init && ./pz.sh start"
}

# ---------------------------------------------------------------------------
# start
# ---------------------------------------------------------------------------
cmd_start() {
  need terraform
  need aws

  [ -f "$TFVARS" ] || die "No $TFVARS found. Run: ./pz.sh setup"

  local profile; profile=$(tfvar aws_profile); profile="${profile:-pz-server}"

  # Turn the EIP back on if it was released during the last stop.
  if grep -qE '^[[:space:]]*use_elastic_ip[[:space:]]*=[[:space:]]*false' "$TFVARS"; then
    info "Re-enabling Elastic IP..."
    # Portable in-place edit (BSD and GNU sed disagree about -i).
    sed 's/^\([[:space:]]*use_elastic_ip[[:space:]]*=[[:space:]]*\)false/\1true/' \
      "$TFVARS" > "$TFVARS.tmp" && mv "$TFVARS.tmp" "$TFVARS"
  fi

  local iid; iid=$(tf_out instance_id)

  if [ -z "$iid" ]; then
    info "No instance in state - running a full apply (first run takes ~10 min)."
    terraform apply || die "terraform apply failed"
  else
    local state
    state=$(aws ec2 describe-instances --instance-ids "$iid" --profile "$profile" \
      --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")

    if [ "$state" = "running" ]; then
      ok "Instance is already running."
    else
      info "Starting instance $iid (currently: $state)..."
      aws ec2 start-instances --instance-ids "$iid" --profile "$profile" >/dev/null \
        || die "Failed to start instance"
      info "Waiting for it to come up..."
      aws ec2 wait instance-running --instance-ids "$iid" --profile "$profile" \
        || warn "Timed out waiting; check the console."
    fi

    # Re-apply so a newly allocated EIP gets written into the DNS record.
    info "Applying to refresh IP and DNS..."
    terraform apply || warn "Apply reported a problem - check output above."
  fi

  echo
  local host ip
  host=$(tf_out server_hostname)
  ip=$(tf_out server_public_ip)
  [ -n "$host" ] && ok "Hostname: ${host}  (port 16261)"
  [ -n "$ip" ]   && ok "IP:       ${ip}"
  echo
  info "The game takes a couple of minutes to finish booting."
  info "Watch it with: ./pz.sh logs"
}

# ---------------------------------------------------------------------------
# stop
# ---------------------------------------------------------------------------
cmd_stop() {
  need terraform
  need aws

  [ -f "$TFVARS" ] || die "No $TFVARS found."

  local profile; profile=$(tfvar aws_profile); profile="${profile:-pz-server}"
  local iid; iid=$(tf_out instance_id)
  [ -n "$iid" ] || die "No instance found in Terraform state - nothing to stop."

  local state
  state=$(aws ec2 describe-instances --instance-ids "$iid" --profile "$profile" \
    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")

  if [ "$state" != "running" ]; then
    warn "Instance is '$state', not running - skipping the graceful save."
  else
    # --- Graceful save. This is the step that protects your world. ---
    local target key
    target=$(tf_out server_public_ip)
    key=$(tfvar ssh_public_key_path)
    key="${key%.pub}" # private key sits alongside the public one

    if [ -z "$target" ]; then
      warn "No public IP available - cannot SSH in to save."
    elif [ ! -f "$key" ]; then
      warn "Private key not found at $key - cannot SSH in to save."
    else
      info "Telling the game to save and shut down cleanly..."
      if ssh -i "$key" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
           "ubuntu@$target" "sudo systemctl stop zomboid" 2>/dev/null; then
        ok "World saved and server stopped."
      else
        warn "Could not reach the server over SSH."
        warn "Progress since the last autosave (every 15 min) may be lost."
        read -r -p "Continue shutting down anyway? [y/N] " reply
        case "$reply" in
          [yY]*) ;;
          *) info "Aborted. Nothing was stopped."; return 1 ;;
        esac
      fi
    fi

    info "Stopping instance $iid..."
    aws ec2 stop-instances --instance-ids "$iid" --profile "$profile" >/dev/null \
      || die "Failed to stop instance"
    aws ec2 wait instance-stopped --instance-ids "$iid" --profile "$profile" \
      || warn "Timed out waiting for stop."
    ok "Instance stopped - compute charges have ended."
  fi

  # --- Release the EIP ---
  # AWS bills for an Elastic IP whenever it isn't attached to a RUNNING
  # instance, so holding one across a long idle period costs money for
  # nothing. Releasing it also removes the DNS record; ./pz.sh start
  # allocates a fresh IP and rewrites the record automatically.
  echo
  read -r -p "Release the Elastic IP too? Saves the idle charge. [Y/n] " reply
  case "$reply" in
    [nN]*)
      info "Keeping the Elastic IP - the address stays stable."
      ;;
    *)
      info "Releasing Elastic IP and removing the DNS record..."
      sed 's/^\([[:space:]]*use_elastic_ip[[:space:]]*=[[:space:]]*\)true/\1false/' \
        "$TFVARS" > "$TFVARS.tmp" && mv "$TFVARS.tmp" "$TFVARS"
      terraform apply || warn "Apply reported a problem - check output above."
      ok "Released."
      ;;
  esac

  echo
  ok "Shut down. Still billing: EBS volumes and snapshots only (a few dollars a month)."
  info "Bring it back with: ./pz.sh start"
}

# ---------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------
cmd_status() {
  need terraform

  local iid; iid=$(tf_out instance_id)
  if [ -z "$iid" ]; then
    warn "Nothing deployed yet (no instance in Terraform state)."
    return 0
  fi

  need aws
  local profile; profile=$(tfvar aws_profile); profile="${profile:-pz-server}"

  local state
  state=$(aws ec2 describe-instances --instance-ids "$iid" --profile "$profile" \
    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")

  echo
  echo "  Instance   $iid"
  case "$state" in
    running) echo "  State      ${GRN}$state${RST}  (compute is billing)" ;;
    stopped) echo "  State      ${YLW}$state${RST}  (compute is not billing)" ;;
    *)       echo "  State      $state" ;;
  esac

  local host ip
  host=$(tf_out server_hostname)
  ip=$(tf_out server_public_ip)
  [ -n "$host" ] && echo "  Hostname   $host"
  [ -n "$ip" ]   && echo "  IP         $ip"

  if grep -qE '^[[:space:]]*use_elastic_ip[[:space:]]*=[[:space:]]*false' "$TFVARS" 2>/dev/null; then
    echo "  Elastic IP ${YLW}released${RST}"
  else
    echo "  Elastic IP allocated"
  fi

  if [ "$state" = "running" ]; then
    echo
    echo "  Passwords:  terraform output -raw server_password"
    echo "              terraform output -raw admin_password"
  fi
  echo
}

# ---------------------------------------------------------------------------
# ssh / logs
# ---------------------------------------------------------------------------
_ssh_target() {
  local target key
  target=$(tf_out server_public_ip)
  [ -n "$target" ] || die "No public IP - is the server running? Try: ./pz.sh start"
  key=$(tfvar ssh_public_key_path); key="${key%.pub}"
  [ -f "$key" ] || die "Private key not found at $key"
  echo "$key|$target"
}

cmd_ssh() {
  local pair; pair=$(_ssh_target) || exit 1
  ssh -i "${pair%|*}" -o StrictHostKeyChecking=accept-new "ubuntu@${pair#*|}"
}

cmd_logs() {
  local pair; pair=$(_ssh_target) || exit 1
  info "Following the game log - Ctrl+C to stop (this does not stop the server)."
  ssh -i "${pair%|*}" -o StrictHostKeyChecking=accept-new -t \
    "ubuntu@${pair#*|}" "sudo journalctl -u zomboid -f"
}

# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Project Zomboid server management

  ./pz.sh setup    Interactive first-time config (writes terraform.tfvars)
  ./pz.sh start    Bring the server up
  ./pz.sh stop     Save the world, shut down, optionally release the EIP
  ./pz.sh status   Show what's running
  ./pz.sh ssh      Shell into the server
  ./pz.sh logs     Follow the game server log

EOF
}

case "${1:-}" in
  setup)  cmd_setup ;;
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  ssh)    cmd_ssh ;;
  logs)   cmd_logs ;;
  ""|-h|--help|help) usage ;;
  *) err "Unknown command: $1"; echo; usage; exit 1 ;;
esac
