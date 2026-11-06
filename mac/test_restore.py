import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).parent / 'setup/restore.sh'
BACKUP = Path(__file__).with_name('backup.sh')


class RestoreTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='restore test ')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        drive_root = self.home / 'Library/CloudStorage/GoogleDrive-test'
        (drive_root / 'My Drive').mkdir(parents=True)
        (self.home / 'Google Drive').symlink_to(drive_root)
        self.backups = self.home / 'Google Drive/My Drive/os_bootstrap_backups'
        self.backups.mkdir(parents=True)

    def archive(self, name, entries):
        path = self.backups / name
        with zipfile.ZipFile(path, 'w') as archive:
            for member, content in entries:
                archive.writestr(member, content)
        return path

    def run_restore(self, input='', success=True):
        result = subprocess.run(['/bin/bash', str(SCRIPT)], env={**os.environ, 'HOME': str(self.home)},
                                input=input, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_fresh_system_restores_real_backup_without_prompt(self):
        (self.home / '.ssh').mkdir()
        (self.home / '.ssh' / 'id key').write_text('secret')
        (self.home / '.ssh' / 'id key').chmod(0o600)
        (self.home / '.pi' / '.empty').mkdir(parents=True)
        (self.home / '.pi' / 'link').symlink_to('../.ssh/id key')
        (self.home / '.gitconfig').write_text('git')
        subprocess.run(['/bin/bash', str(BACKUP)], env={**os.environ, 'HOME': str(self.home)}, check=True,
                       capture_output=True)
        (self.home / '.ssh' / 'id key').unlink()
        (self.home / '.ssh').rmdir()
        (self.home / '.pi' / 'link').unlink()
        (self.home / '.pi' / '.empty').rmdir()
        (self.home / '.pi').rmdir()
        (self.home / '.gitconfig').unlink()
        result = self.run_restore()
        self.assertNotIn('Continue with restore?', result.stdout)
        for path in ('.ssh/id key', '.pi/.empty', '.pi/link', '.gitconfig'):
            self.assertIn(repr(path), result.stdout)
        self.assertEqual((self.home / '.ssh/id key').read_text(), 'secret')
        self.assertEqual(stat.S_IMODE((self.home / '.ssh/id key').stat().st_mode), 0o600)
        self.assertTrue((self.home / '.pi/.empty').is_dir())
        self.assertEqual(os.readlink(self.home / '.pi/link'), '../.ssh/id key')
        self.assertEqual((self.home / '.gitconfig').read_text(), 'git')

    def test_existing_directories_merge_without_prompt_when_files_do_not_collide(self):
        self.archive('os_bootstrap_1.zip', [('.ssh/', b''), ('.ssh/key', b'new key'),
                                            ('.pi/nested/config', b'new config')])
        (self.home / '.ssh').mkdir(mode=0o700)
        (self.home / '.ssh/existing').write_text('keep')
        (self.home / '.pi/nested').mkdir(parents=True)
        result = self.run_restore()
        self.assertNotIn('Continue with restore?', result.stdout)
        self.assertIn('Restore complete.', result.stdout)
        self.assertEqual((self.home / '.ssh/key').read_text(), 'new key')
        self.assertEqual((self.home / '.ssh/existing').read_text(), 'keep')
        self.assertEqual((self.home / '.pi/nested/config').read_text(), 'new config')
        self.assertEqual(stat.S_IMODE((self.home / '.ssh').stat().st_mode), 0o700)

    def test_conflicts_are_listed_and_decline_changes_nothing(self):
        self.archive('os_bootstrap_1.zip', [('.ssh/', b''), ('.ssh/key', b'new'),
                                            ('.gitconfig', b'new'), ('.zsh_history', b'new')])
        (self.home / '.ssh').mkdir()
        (self.home / '.ssh/key').write_text('old key')
        (self.home / '.gitconfig').write_text('old git')
        result = self.run_restore('n\n')
        self.assertIn('Continue with restore?', result.stdout)
        conflicts = result.stdout.split('Existing destination paths')[1]
        for path in ('.ssh/key', '.gitconfig'):
            self.assertIn(repr(path), conflicts)
        self.assertNotIn(repr('.ssh'), conflicts)
        self.assertNotIn(repr('.zsh_history'), conflicts)
        self.assertEqual((self.home / '.ssh/key').read_text(), 'old key')
        self.assertEqual((self.home / '.gitconfig').read_text(), 'old git')
        self.assertFalse((self.home / '.zsh_history').exists())

    def test_accept_overwrites_files_without_following_leaf_symlink(self):
        self.archive('os_bootstrap_1.zip', [('.gitconfig', b'new'), ('.ssh/key', b'key')])
        outside = self.home.parent / (self.home.name + '-outside')
        outside.write_text('outside')
        self.addCleanup(outside.unlink)
        (self.home / '.gitconfig').symlink_to(outside)
        result = self.run_restore('yes\n')
        self.assertIn('Continue with restore?', result.stdout)
        self.assertFalse((self.home / '.gitconfig').is_symlink())
        self.assertEqual((self.home / '.gitconfig').read_text(), 'new')
        self.assertEqual(outside.read_text(), 'outside')
        self.assertEqual((self.home / '.ssh/key').read_text(), 'key')

    def test_restored_symlink_collision_prompts(self):
        link = zipfile.ZipInfo('.ssh/link')
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        self.archive('os_bootstrap_1.zip', [(link, b'new-target')])
        (self.home / '.ssh').mkdir()
        existing = self.home / '.ssh/link'
        existing.symlink_to('missing-target')
        result = self.run_restore('n\n')
        self.assertIn('Continue with restore?', result.stdout)
        self.assertIn(repr('.ssh/link'), result.stdout.split('Existing destination paths')[1])
        self.assertEqual(os.readlink(existing), 'missing-target')
        result = self.run_restore('y\n')
        self.assertIn('Continue with restore?', result.stdout)
        self.assertEqual(os.readlink(existing), 'new-target')

    def test_invalid_paths_and_corrupt_archive_are_skipped_for_newest_valid(self):
        good = self.archive('os_bootstrap_good.zip', [('.gitconfig', b'good')])
        bad = self.archive('os_bootstrap_bad.zip', [('../escape', b'bad')])
        corrupt = self.backups / 'os_bootstrap_corrupt.zip'
        corrupt.write_bytes(b'not a zip')
        for path, timestamp in ((good, 100), (bad, 200), (corrupt, 300)):
            os.utime(path, (timestamp, timestamp))
        result = self.run_restore()
        self.assertEqual(result.stderr.count('Skipping invalid archive'), 2)
        self.assertEqual((self.home / '.gitconfig').read_text(), 'good')
        self.assertFalse((self.home.parent / 'escape').exists())

    def test_unsafe_paths_fail_without_writes(self):
        for name in ('../escape', '/tmp/escape', '.ssh/../../escape', '.ssh/./key',
                     '.ssh\\key', 'other/file'):
            with self.subTest(name=name):
                path = self.archive('os_bootstrap_bad.zip', [('.gitconfig', b'new'), (name, b'bad')])
                result = self.run_restore(success=False)
                self.assertIn('No valid backup archives', result.stderr)
                self.assertFalse((self.home / '.gitconfig').exists())
                path.unlink()

    def test_archive_symlink_parent_and_existing_symlink_parent_rejected(self):
        link = zipfile.ZipInfo('.ssh')
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        path = self.archive('os_bootstrap_bad.zip', [(link, b'/tmp'), ('.ssh/key', b'bad')])
        self.run_restore(success=False)
        path.unlink()
        self.archive('os_bootstrap_good.zip', [('.ssh/key', b'bad')])
        outside = self.home / 'outside'
        outside.mkdir()
        (self.home / '.ssh').symlink_to(outside, target_is_directory=True)
        self.run_restore(success=False)
        self.assertEqual(list(outside.iterdir()), [])

    def test_eof_declines_and_newest_valid_archive_is_selected(self):
        old = self.archive('os_bootstrap_old.zip', [('.gitconfig', b'old backup')])
        new = self.archive('os_bootstrap_new.zip', [('.gitconfig', b'new backup')])
        os.utime(old, (100, 100))
        os.utime(new, (200, 200))
        (self.home / '.gitconfig').write_text('current')
        result = self.run_restore()
        self.assertIn('Restore declined', result.stdout)
        self.assertEqual((self.home / '.gitconfig').read_text(), 'current')
        self.run_restore('y\n')
        self.assertEqual((self.home / '.gitconfig').read_text(), 'new backup')

    def test_bad_crc_is_skipped_before_writing(self):
        good = self.archive('os_bootstrap_good.zip', [('.gitconfig', b'good')])
        bad = self.archive('os_bootstrap_bad.zip', [('.gitconfig', b'bad content')])
        data = bad.read_bytes().replace(b'bad content', b'BAD CONTENT')
        bad.write_bytes(data)
        os.utime(good, (100, 100))
        os.utime(bad, (200, 200))
        result = self.run_restore()
        self.assertIn('Skipping invalid archive', result.stderr)
        self.assertEqual((self.home / '.gitconfig').read_text(), 'good')

    def test_missing_archives_fail(self):
        self.run_restore(success=False)
        self.backups.rmdir()
        self.run_restore(success=False)


if __name__ == '__main__':
    unittest.main()
