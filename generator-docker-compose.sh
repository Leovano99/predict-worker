#!/bin/bash
set -euo pipefail

WORKERS=${1:-20}
OUTPUT="docker-compose.generated.yml"

echo "Generating $WORKERS workers into $OUTPUT..."

cat <<EOF > $OUTPUT
version: "3.9"

x-worker-common: &worker-common
  image: predict-worker:latest
  stdin_open: true
  tty: true
  restart: unless-stopped

services:
EOF

for i in $(seq 1 $WORKERS); do
  ENV_FILE=".env.worker$i"

  if [ -f "$ENV_FILE" ]; then
    echo "Using $ENV_FILE"
    ENV_BLOCK="      - .env\n      - $ENV_FILE"
  else
    echo "⚠️  $ENV_FILE not found, using .env"
    ENV_BLOCK="      - .env"
  fi

cat <<EOF >> $OUTPUT
  worker$i:
    <<: *worker-common
    container_name: predict-worker-$i
    env_file:
$ENV_BLOCK
    volumes:
      - .:/app
      - worker${i}_wallet:/root/.openclaw-wallet
      - worker${i}_agent:/root/.predict-agent

EOF
done

echo "volumes:" >> $OUTPUT

for i in $(seq 1 $WORKERS); do
cat <<EOF >> $OUTPUT
  worker${i}_wallet:
  worker${i}_agent:
EOF
done

echo "✅ Done: $OUTPUT"
echo "👉 Run with: docker compose -f $OUTPUT up -d"
