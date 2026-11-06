#!/bin/bash
# Requires Xcode Command Line Tools.
set -eu
exec /usr/bin/python3 - <<'PY'
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import zipfile

home = Path.home()
google_drive = home / 'Google Drive'
cloud_storage = home / 'Library/CloudStorage'
state_dir = home / 'Library/Application Support/os_bootstrap'
state_file = state_dir / 'backup-state.json'
sources = ('.ssh', '.gitconfig', '.zsh_history', '.zshrc.work', '.pi')
archive_pattern = re.compile(r'^os_bootstrap_\d{8}T\d{6}\.\d{6}Z\.zip$')


def add_field(digest, value):
    digest.update(len(value).to_bytes(8, 'big'))
    digest.update(value)


def add_entry(archive, digest, path, name):
    info = path.lstat()
    mode = info.st_mode
    entry = zipfile.ZipInfo(name + ('/' if stat.S_ISDIR(mode) else ''))
    entry.create_system = 3
    entry.external_attr = mode << 16
    entry.compress_type = zipfile.ZIP_DEFLATED
    add_field(digest, os.fsencode(entry.filename))
    if stat.S_ISLNK(mode):
        target = os.fsencode(os.readlink(path))
        add_field(digest, b'link')
        add_field(digest, target)
        archive.writestr(entry, target)
    elif stat.S_ISDIR(mode):
        add_field(digest, b'directory')
        archive.writestr(entry, b'')
        with os.scandir(path) as entries:
            children = sorted((e.name for e in entries), key=os.fsencode)
        for child in children:
            add_entry(archive, digest, path / child, name + '/' + child)
    elif stat.S_ISREG(mode):
        add_field(digest, b'file')
        # Hash bytes as they are archived.
        content_hash = hashlib.sha256()
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, 'rb') as source, archive.open(entry, 'w', force_zip64=True) as dest:
            while True:
                chunk = source.read(1024 * 1024)
                if not chunk:
                    break
                content_hash.update(chunk)
                dest.write(chunk)
        add_field(digest, content_hash.digest())
    else:
        raise RuntimeError('Unsupported source type: ' + str(path))


def main():
    if not google_drive.is_symlink():
        raise RuntimeError('Google Drive home link is missing; run the macOS Ansible playbook first')
    drive_root = google_drive.resolve(strict=True)
    if drive_root.parent != cloud_storage.resolve(strict=True) or not drive_root.name.startswith('GoogleDrive-'):
        raise RuntimeError('Google Drive home link does not target Google Drive for desktop storage')
    my_drive = drive_root / 'My Drive'
    if not my_drive.is_dir():
        raise RuntimeError('Google Drive My Drive folder is not available')
    backup_dir = my_drive / 'os_bootstrap_backups'
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Prevent overlapping runs.
    with (state_dir / 'backup.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        present = [name for name in sources if os.path.lexists(home / name)]
        if not present:
            print('No backup sources found; leaving existing backups unchanged.')
            return
        backup_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        digest = hashlib.sha256()
        temp_name = None
        try:
            with tempfile.NamedTemporaryFile(prefix='.backup-', suffix='.tmp', dir=backup_dir, delete=False) as temp:
                temp_name = temp.name
            with zipfile.ZipFile(temp_name, 'w') as archive:
                for name in present:
                    add_entry(archive, digest, home / name, name)
            checksum = digest.hexdigest()
            try:
                state = json.loads(state_file.read_text())
                unchanged = (state['digest'] == checksum and
                             archive_pattern.fullmatch(state['archive']) and
                             (backup_dir / state['archive']).is_file())
            except (OSError, ValueError, KeyError, TypeError):
                unchanged = False
            if unchanged:
                print('Backup content unchanged; no archive created.')
                return
            timestamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
            archive_name = 'os_bootstrap_' + timestamp + '.zip'
            os.replace(temp_name, backup_dir / archive_name)
            temp_name = None
            # Commit state only after the archive succeeds.
            state_temp = None
            try:
                with tempfile.NamedTemporaryFile(mode='w', dir=state_dir, prefix='.backup-state-', delete=False) as f:
                    state_temp = f.name
                    json.dump({'digest': checksum, 'archive': archive_name}, f)
                os.replace(state_temp, state_file)
                state_temp = None
            finally:
                if state_temp is not None:
                    os.unlink(state_temp)
            archives = sorted((p for p in backup_dir.iterdir() if archive_pattern.fullmatch(p.name) and p.is_file()),
                              key=lambda p: p.name, reverse=True)
            for old in archives[5:]:
                old.unlink()
            print('Created ' + str(backup_dir / archive_name))
        finally:
            if temp_name is not None:
                os.unlink(temp_name)


try:
    main()
except Exception as exc:
    print('Backup failed: ' + str(exc), file=sys.stderr)
    sys.exit(1)
PY
