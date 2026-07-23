#!/usr/bin/env bash

set -e

# -------- CONFIG --------
ENV_LOCAL=".env.local"
ENV_PROD=".env.prod"
SCRIPT_BASE="./automation"
# ------------------------

# -------- HELP --------
function usage() {
  echo "Usage: expenvs [run local|run prod]"
  exit 1
}

if [ $# -lt 2 ] || [ "$1" != "run" ]; then
  usage
fi

MODE="$2"

# -------- LOAD ENV --------
if [ "$MODE" == "local" ]; then
  ENV_FILE="$ENV_LOCAL"
elif [ "$MODE" == "prod" ]; then
  ENV_FILE="$ENV_PROD"
else
  usage
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE not found in $(pwd)"
  exit 1
fi

echo "🔐 Loading $ENV_FILE"

# Export env vars
set -a
source "$ENV_FILE"
set +a

# -------- FIND SCRIPTS --------
mapfile -t scripts < <(find "$SCRIPT_BASE" -type f \( -name "*$MODE*" -o -name "*.sh" -o -name "*.py" -o -name "*.yml" -o -name "*.yaml" \) 2>/dev/null)

if [ ${#scripts[@]} -eq 0 ]; then
  echo "❌ No scripts found in $SCRIPT_BASE for mode: $MODE"
  exit 1
fi

# -------- SELECT SCRIPT --------
echo ""
echo "📂 Select a script to run:"
for i in "${!scripts[@]}"; do
  echo "$((i+1))) ${scripts[$i]}"
done

echo ""
read -p "Enter number: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#scripts[@]}" ]; then
  echo "❌ Invalid selection"
  exit 1
fi

script="${scripts[$((choice-1))]}"

echo ""
echo "🚀 Running: $script"
echo ""

# -------- RUN SCRIPT --------
case "$script" in
  *.sh)
    exec bash "$script"
    ;;
  *.py)
    exec python3 "$script"
    ;;
  *.yml|*.yaml)
    exec ansible-playbook "$script"
    ;;
  *)
    echo "❌ Unsupported file type"
    exit 1
    ;;
esac