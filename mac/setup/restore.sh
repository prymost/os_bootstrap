#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

DEFAULT_BACKUP_DIR="$HOME/my_backup"
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
declare -a SOURCES=(
  "$BACKUP_DIR/.zshrc" 
  "$BACKUP_DIR/.zsh_history" 
  "$BACKUP_DIR/.ssh"
  "$BACKUP_DIR/.gitconfig"
  "$BACKUP_DIR/.aws"
)

echo "***** Timestamp $(date) *****"

for i in "${SOURCES[@]}"
do
  echo " Copying $i to $HOME "
  cp -R $i $HOME
done
