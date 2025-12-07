#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# Separator
sep() { echo -e "${CYAN}========================================${NC}"; }

# Check Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} current directory is not a Git repository."
    exit 1
fi

REPO_DIR=$(git rev-parse --show-toplevel)
PROJECT_NAME=$(basename "$REPO_DIR")

# Detect first mapped Samba share
SAMBA_BASE=$(mount | grep cifs | awk '{print $3}' | head -n1)
if [ -z "$SAMBA_BASE" ]; then
    echo -e "${RED}No mapped Samba share found.${NC}"
    exit 1
fi

SAMBA_DIR="$SAMBA_BASE/Env/$PROJECT_NAME"
echo -e "${CYAN}Repository:${NC} $REPO_DIR"
echo -e "${CYAN}Samba share:${NC} $SAMBA_DIR"

# Confirmation
read -p "Are you sure you want to sync .env files and install dependencies? [y/N]: " confirm
confirm=${confirm,,}
if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
    echo "Operation cancelled."
    exit 0
fi

sep
# Git pull
echo -e "${YELLOW}Running git pull...${NC}"
git pull
sep

# Install dependencies
echo -e "${YELLOW}Checking dependencies in directories with package.json...${NC}"
find "$REPO_DIR" \
  -path "*/node_modules/*" -prune -o \
  -path "*/.git/*" -prune -o \
  -path "*/.next/*" -prune -o \
  -path "*/dist/*" -prune -o \
  -path "*/build/*" -prune -o \
  -path "*/out/*" -prune -o \
  -path "*/tmp/*" -prune -o \
  -path "*/coverage/*" -prune -o \
  -name "package.json" -print0 |
while IFS= read -r -d '' pkg; do
    dir=$(dirname "$pkg")
    echo -e "${CYAN}[$dir]${NC} checking dependencies..."
    cd "$dir" || continue

    if [ -f "pnpm-lock.yaml" ] || [ -f "pnpm-lock.yml" ]; then
        echo -e "${GREEN}[$dir] pnpm install${NC}"
        pnpm install
    elif [ -f "yarn.lock" ]; then
        echo -e "${GREEN}[$dir] yarn install${NC}"
        yarn install
    elif [ -f "package-lock.json" ]; then
        echo -e "${GREEN}[$dir] npm install${NC}"
        npm install
    else
        echo -e "${YELLOW}[$dir] no lockfile → npm install${NC}"
        npm install
    fi

    cd - >/dev/null
done
sep

# Two-way sync of .env files
echo -e "${YELLOW}Synchronizing .env files...${NC}"
mkdir -p "$SAMBA_DIR"

find "$REPO_DIR" -type f -name ".env*" | while read envfile; do
    rel_path=$(realpath --relative-to="$REPO_DIR" "$(dirname "$envfile")")
    filename=$(basename "$envfile")
    clean_filename="${filename#.}"

    if [ -z "$rel_path" ] || [ "$rel_path" = "." ]; then
        prefix="root"
    else
        prefix=$(echo "$rel_path" | tr '/' '_')
    fi

    samba_filename="${prefix}.${clean_filename}"
    samba_env="$SAMBA_DIR/$samba_filename"
    mkdir -p "$(dirname "$samba_env")"

    if [ -f "$samba_env" ]; then
        local_mod=$(stat -c %Y "$envfile")
        samba_mod=$(stat -c %Y "$samba_env")

        if [ "$local_mod" -gt "$samba_mod" ]; then
            cp "$envfile" "$samba_env"
            echo -e "${GREEN}Updated on Samba:${NC} $samba_filename"
        elif [ "$samba_mod" -gt "$local_mod" ]; then
            cp "$samba_env" "$envfile"
            echo -e "${GREEN}Updated locally:${NC} $filename"
        else
            echo -e "${CYAN}File $filename is up to date${NC}"
        fi
    else
        cp "$envfile" "$samba_env"
        echo -e "${GREEN}Created $samba_filename on Samba${NC}"
    fi
done
sep
echo -e "${GREEN}Done.${NC}"