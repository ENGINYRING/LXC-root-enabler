#!/bin/bash

ARCHIVE_DIR="/var/lib/vz/template/cache"
TMP_DIR="/tmp/lxc_template_edit"
LOG_DIR="/var/lib/vz/template"
LOG_FILE="$LOG_DIR/edited_templates.log"

mkdir -p "$LOG_DIR"
mkdir -p "$TMP_DIR"
touch "$LOG_FILE"

for archive in "$ARCHIVE_DIR"/*.{tar.gz,tar.xz}; do
  [ -e "$archive" ] || continue
  
  filename=$(basename "$archive")

  if grep -Fxq "$filename" "$LOG_FILE"; then
    echo "Skipping $filename, already processed."
    continue
  fi

  echo "Processing $filename"

  rm -rf "$TMP_DIR"/*

  # Extract archive
  case "$archive" in
    *.tar.gz)
      tar -xzf "$archive" -C "$TMP_DIR"
      ;;
    *.tar.xz)
      tar -xJf "$archive" -C "$TMP_DIR"
      ;;
    *)
      echo "Unsupported archive type: $filename"
      continue
      ;;
  esac

  # Mount needed filesystems for chroot
  mount --bind /proc "$TMP_DIR/proc"
  mount --bind /sys "$TMP_DIR/sys"
  mount --bind /dev "$TMP_DIR/dev"
  mount --bind /etc/resolv.conf "$TMP_DIR/etc/resolv.conf"

  # Detect package manager
  if chroot "$TMP_DIR" command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
  elif chroot "$TMP_DIR" command -v yum >/dev/null 2>&1; then
    PKG_MGR="yum"
  elif chroot "$TMP_DIR" command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt-get"
  else
    echo "No known package manager found in $filename, skipping ssh install."
    PKG_MGR=""
  fi

  if [ -n "$PKG_MGR" ]; then
    # Check if sshd installed
    if ! chroot "$TMP_DIR" command -v sshd >/dev/null 2>&1; then
      echo "sshd not found, installing in $filename"
      if [ "$PKG_MGR" = "apt-get" ]; then
        chroot "$TMP_DIR" apt-get update
        chroot "$TMP_DIR" apt-get install -y openssh-server
      else
        chroot "$TMP_DIR" $PKG_MGR install -y openssh-server
      fi
    else
      echo "sshd already installed in $filename"
    fi
  fi

  # Unmount before editing
  umount "$TMP_DIR/etc/resolv.conf"
  umount "$TMP_DIR/proc"
  umount "$TMP_DIR/sys"
  umount "$TMP_DIR/dev"

  SSHD_CONF="$TMP_DIR/etc/ssh/sshd_config"

  if [ ! -f "$SSHD_CONF" ]; then
    echo "sshd_config still not found in $filename, skipping editing."
    continue
  fi

  cp "$SSHD_CONF" "$SSHD_CONF.bak"

  # Update sshd_config
  if grep -qE '^[#\s]*PermitRootLogin' "$SSHD_CONF"; then
    sed -i 's/^[#\s]*PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONF"
  else
    echo "PermitRootLogin yes" >> "$SSHD_CONF"
  fi

  if grep -qE '^[#\s]*PasswordAuthentication' "$SSHD_CONF"; then
    sed -i 's/^[#\s]*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONF"
  else
    echo "PasswordAuthentication yes" >> "$SSHD_CONF"
  fi

  echo "Repacking $filename"
  cd "$TMP_DIR" || exit 1
  case "$archive" in
    *.tar.gz)
      tar -czf "$archive" ./*
      ;;
    *.tar.xz)
      tar -cJf "$archive" ./*
      ;;
  esac
  cd - > /dev/null

  echo "$filename" >> "$LOG_FILE"
  echo "Done $filename"
done

rm -rf "$TMP_DIR"
