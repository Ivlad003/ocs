#!/bin/sh
# інсталятор ocs:  curl -fsSL https://raw.githubusercontent.com/Ivlad003/ocs/main/install.sh | sh
# OCS_INSTALL_DIR — куди класти (типово ~/.local/bin), OCS_REF — гілка/тег (типово main)

set -eu

REPO="Ivlad003/ocs"
REF="${OCS_REF:-main}"
DIR="${OCS_INSTALL_DIR:-$HOME/.local/bin}"
URL="https://raw.githubusercontent.com/$REPO/$REF/ocs"

mkdir -p "$DIR"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "завантажую $URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$tmp"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp" "$URL"
else
  echo "потрібен curl або wget" >&2; exit 1
fi

# захист від HTML-сторінки помилки замість скрипта
head -1 "$tmp" | grep -q '^#!/usr/bin/env bash' || { echo "завантажено не скрипт ocs" >&2; exit 1; }

chmod 755 "$tmp"
mv "$tmp" "$DIR/ocs"
trap - EXIT
echo "встановлено: $DIR/ocs"

case ":$PATH:" in
  *":$DIR:"*) : ;;
  *) echo
     echo "  $DIR немає в PATH — додай у ~/.zshrc або ~/.bashrc:"
     echo "    export PATH=\"$DIR:\$PATH\"" ;;
esac

# залежності лише підказуємо — ocs сам пояснить, як їх поставити
for t in tailscale opencode; do
  command -v "$t" >/dev/null 2>&1 || echo "  (ще потрібен $t — ocs підкаже, як встановити)"
done
echo
echo "далі:  ocs help"
