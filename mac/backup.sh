#!/bin/bash
set -uo pipefail
IFS=$'\n\t'

DEFAULT_BACKUP_DIR="$HOME/my_backup"
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
declare -a SOURCES=(
  "$HOME/.zshrc" 
  "$HOME/.zsh_history" 
  "$HOME/.ssh"
  "$HOME/.gitconfig"
  # "$HOME/.aws"
)

echo "***** Timestamp $(date) *****"

echo "***** Removing $BACKUP_DIR *****"
rm -rf $BACKUP_DIR

echo "***** Creating $BACKUP_DIR *****"
mkdir -p $BACKUP_DIR

for i in "${SOURCES[@]}"
do
  echo "***** Copying $i *****"
  cp -R $i $BACKUP_DIR
done
