#!/bin/bash
# Requires Xcode Command Line Tools.
set -eu
exec /usr/bin/python3 -c "$(cat <<'PY'
import os
from pathlib import Path
import stat
import struct
import sys
import zipfile
import zlib

home = Path.home()
backup_dir = home / 'Google Drive/My Drive/os_bootstrap_backups'
sources = {'.ssh', '.gitconfig', '.zsh_history', '.zshrc.work', '.pi'}


def inspect_archive(archive):
    """Validate all entries before writing."""
    entries = {}
    for info in archive.infolist():
        name = info.orig_filename
        if (not name or '\x00' in name or '\\' in name or name.startswith('/') or
                any(part in ('', '.', '..') for part in name.rstrip('/').split('/'))):
            raise ValueError('unsafe archive path: ' + repr(name))
        parts = name.rstrip('/').split('/')
        if parts[0] not in sources:
            raise ValueError('unexpected archive path: ' + repr(name))
        path = '/'.join(parts)
        if path in entries:
            raise ValueError('duplicate archive path: ' + repr(path))
        mode = info.external_attr >> 16
        kind = stat.S_IFMT(mode)
        if info.is_dir():
            if kind not in (0, stat.S_IFDIR):
                raise ValueError('invalid directory type: ' + repr(name))
            entry_type = 'directory'
        elif kind in (0, stat.S_IFREG):
            entry_type = 'file'
        elif kind == stat.S_IFLNK:
            entry_type = 'symlink'
        else:
            raise ValueError('unsupported archive entry: ' + repr(name))
        entries[path] = (entry_type, info, mode)

    if not entries:
        raise ValueError('empty archive')
    for path in list(entries):
        parts = path.split('/')
        for i in range(1, len(parts)):
            parent = '/'.join(parts[:i])
            if parent in entries and entries[parent][0] != 'directory':
                raise ValueError('non-directory archive parent: ' + repr(parent))
            if parent not in entries:
                entries[parent] = ('directory', None, 0o700)
    # Check member data before writing.
    for path, (entry_type, info, _) in entries.items():
        if info is None:
            continue
        if entry_type == 'symlink':
            target = archive.read(info)
            if not target or b'\x00' in target:
                raise ValueError('invalid symlink target: ' + repr(path))
        else:
            with archive.open(info) as source:
                while source.read(1024 * 1024):
                    pass
    return entries


def main():
    if not backup_dir.is_dir():
        raise ValueError('Backup directory not found: ' + str(backup_dir))
    candidates = sorted(backup_dir.glob('os_bootstrap_*.zip'),
                        key=lambda p: (p.stat().st_mtime_ns, p.name), reverse=True)
    if not candidates:
        raise ValueError('No backup archives found in ' + str(backup_dir))
    archive = None
    for candidate in candidates:
        try:
            archive = zipfile.ZipFile(candidate)
            entries = inspect_archive(archive)
            break
        except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, NotImplementedError,
                EOFError, struct.error, zlib.error) as exc:
            if archive is not None:
                archive.close()
                archive = None
            print('Skipping invalid archive {}: {}'.format(candidate, exc), file=sys.stderr)
    if archive is None:
        raise ValueError('No valid backup archives found in ' + str(backup_dir))

    with archive:
        ordered = sorted(entries, key=lambda p: (p.count('/'), p))
        print('Archive: ' + str(candidate))
        print('Paths to restore (relative to home):')
        for path in sorted(entries):
            print('  ' + repr(path) + ('/' if entries[path][0] == 'directory' else ''))

        conflicts = []
        for path in ordered:
            dest = home / path
            if not os.path.lexists(dest):
                continue
            mode = dest.lstat().st_mode
            entry_type = entries[path][0]
            if entry_type == 'directory':
                if not stat.S_ISDIR(mode):
                    raise ValueError('Destination directory is blocked by a file or symlink: ' + str(dest))
                continue
            if stat.S_ISDIR(mode):
                raise ValueError('Destination file is blocked by a directory: ' + str(dest))
            conflicts.append((path, entry_type))
        if conflicts:
            print('Existing destination paths (files/links will be overwritten):')
            for path, _ in conflicts:
                print('  ' + repr(path))
            try:
                answer = input('Continue with restore? [y/N] ')
            except EOFError:
                answer = ''
            if answer.strip().lower() not in ('y', 'yes'):
                print('Restore declined; no changes made.')
                return

        created_dirs = []
        for path in ordered:
            entry_type, info, mode = entries[path]
            dest = home / path
            if entry_type == 'directory':
                if not os.path.lexists(dest):
                    dest.mkdir(mode=0o700)
                    created_dirs.append((dest, mode))
            elif entry_type == 'symlink':
                if os.path.lexists(dest):
                    dest.unlink()
                os.symlink(os.fsdecode(archive.read(info)), dest)
            else:
                # Replace the link itself, not its target.
                if os.path.lexists(dest):
                    dest.unlink()
                with archive.open(info) as source, dest.open('xb') as output:
                    while True:
                        chunk = source.read(1024 * 1024)
                        if not chunk:
                            break
                        output.write(chunk)
                os.chmod(dest, stat.S_IMODE(mode) if mode else 0o600)
        for dest, mode in reversed(created_dirs):
            os.chmod(dest, stat.S_IMODE(mode) if mode else 0o700)
        print('Restore complete.')


try:
    main()
except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, NotImplementedError,
        EOFError, struct.error, zlib.error) as exc:
    print('Restore failed: ' + str(exc), file=sys.stderr)
    sys.exit(1)
PY
)"
