#!/bin/bash
set -e
set -x

echo "=== START ENTRYPOINT ==="

echo "Node: $(node -v)"
echo "NPM: $(npm -v)"
echo "Python: $(python --version)"

# =========================
# AWP WALLET SETUP
# =========================

if [ ! -d "/app/awp-wallet" ]; then
  git clone https://github.com/awp-core/awp-wallet /app/awp-wallet
fi

cd /app/awp-wallet

if ! command -v awp-wallet >/dev/null 2>&1; then
  echo "Installing awp-wallet..."

  chmod +x install.sh

  if [ -n "$MNEMONIC" ]; then
    bash ./install.sh --mnemonic "$MNEMONIC"
  else
    bash ./install.sh
  fi
else
  echo "awp-wallet already installed"
fi

# Normalize awp-wallet binary
AWP_PATH="$(which awp-wallet || true)"

if [ -z "$AWP_PATH" ]; then
  if [ -f "$HOME/.local/bin/awp-wallet" ]; then
    AWP_PATH="$HOME/.local/bin/awp-wallet"
  elif [ -f "/usr/bin/awp-wallet" ]; then
    AWP_PATH="/usr/bin/awp-wallet"
  else
    echo "FATAL: awp-wallet not found"
    exit 1
  fi
fi

ln -sf "$AWP_PATH" /usr/local/bin/awp-wallet

which awp-wallet
awp-wallet --help || true

# =========================
# PREDICTION SKILL SETUP
# =========================

cd /app

if [ ! -d "/app/prediction-skill" ]; then
  git clone https://github.com/Leovano99/prediction-skill
fi

cd /app/prediction-skill

# Install predict-agent
if ! command -v predict-agent >/dev/null 2>&1; then
  echo "Installing predict-agent..."

  chmod +x install.sh
  sh ./install.sh
else
  echo "predict-agent already installed"
fi

# Verify
which predict-agent
predict-agent --version || true

# =========================
# RETRY HELPER
# =========================

retry() {
  local retries=5
  local delay=5
  local count=1

  until "$@"; do
    if [ $count -ge $retries ]; then
      echo "Command failed after $count attempts: $*"
      return 1
    fi

    echo "Attempt $count failed. Retrying in ${delay}s..."
    count=$((count+1))
    sleep $delay
  done
}

# =========================
# PREDICT-AGENT INIT (ALWAYS RUN)
# =========================

echo "Running predict-agent preflight (with retry)..."
retry predict-agent preflight || true

echo "Setting persona (with retry)..."
retry predict-agent set-persona conservative || true

# =========================
# OPENCLAW SETUP
# =========================

OPENCLAW_SRC="/app/prediction-skill/openclaw-mock/openclaw"

if [ -f "$OPENCLAW_SRC" ]; then
  chmod +x "$OPENCLAW_SRC"
  ln -sf "$OPENCLAW_SRC" /usr/local/bin/openclaw
else
  echo "ERROR: openclaw not found"
  exit 1
fi

which openclaw || true

# =========================
# WALLET POST ACTION
# =========================

if [ -z "$MNEMONIC" ]; then
  echo "No mnemonic → showing wallet info"
  awp-wallet receive
  awp-wallet export
else
  echo "Mnemonic provided → wallet already initialized"
fi

echo "=== ENTRYPOINT DONE ==="

# keep container alive
tail -f /dev/null
