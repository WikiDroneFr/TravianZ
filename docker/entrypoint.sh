#!/bin/sh
set -eu

APP_DIR="/var/www/html"
RUNTIME_DIR="/var/lib/travianz-runtime"
SEED_DIR="/usr/local/share/travianz-runtime-seed"

mkdir -p \
    "$RUNTIME_DIR/var" \
    "$RUNTIME_DIR/Prevention" \
    "$RUNTIME_DIR/Notes" \
    "$RUNTIME_DIR/Templates" \
    "$RUNTIME_DIR/GameEngine/Admin/Mods"

# Initialise the persistent runtime volume only once.
if [ ! -e "$RUNTIME_DIR/.initialized" ]; then
    cp -a "$SEED_DIR/var/." "$RUNTIME_DIR/var/"
    cp -a "$SEED_DIR/Prevention/." "$RUNTIME_DIR/Prevention/"
    cp -a "$SEED_DIR/Notes/." "$RUNTIME_DIR/Notes/"

    cp "$SEED_DIR/text.tpl" \
       "$RUNTIME_DIR/Templates/text.tpl"

    touch "$RUNTIME_DIR/.initialized"
fi

# Replace writable application paths with persistent runtime links.
rm -rf "$APP_DIR/var"
ln -s "$RUNTIME_DIR/var" "$APP_DIR/var"

rm -rf "$APP_DIR/GameEngine/Prevention"
ln -s "$RUNTIME_DIR/Prevention" "$APP_DIR/GameEngine/Prevention"

rm -rf "$APP_DIR/GameEngine/Notes"
ln -s "$RUNTIME_DIR/Notes" "$APP_DIR/GameEngine/Notes"

rm -f "$APP_DIR/Templates/text.tpl"
ln -s "$RUNTIME_DIR/Templates/text.tpl" "$APP_DIR/Templates/text.tpl"

rm -f "$APP_DIR/GameEngine/config.php"
ln -s "$RUNTIME_DIR/GameEngine/config.php" \
      "$APP_DIR/GameEngine/config.php"

rm -f "$APP_DIR/GameEngine/Admin/Mods/constant_format.tpl"
ln -s "$RUNTIME_DIR/GameEngine/Admin/Mods/constant_format.tpl" \
      "$APP_DIR/GameEngine/Admin/Mods/constant_format.tpl"

rm -f "$APP_DIR/automation.lck"
ln -s "$RUNTIME_DIR/automation.lck" \
      "$APP_DIR/automation.lck"

# The installer and administration panel run as www-data.
chown -R www-data:www-data "$RUNTIME_DIR"
find "$RUNTIME_DIR" -type d -exec chmod 750 {} \;
find "$RUNTIME_DIR" -type f -exec chmod 640 {} \;

exec "$@"
