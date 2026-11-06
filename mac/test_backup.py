import json
import os
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).with_name("backup.sh")


class BackupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="backup test ")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        drive_root = self.home / "Library/CloudStorage/GoogleDrive-test"
        (drive_root / "My Drive").mkdir(parents=True)
        (self.home / "Google Drive").symlink_to(drive_root)
        self.backups = self.home / "Google Drive/My Drive/os_bootstrap_backups"
        self.state = (
            self.home / "Library/Application Support/os_bootstrap/backup-state.json"
        )

    def run_backup(self, success=True):
        result = subprocess.run(
            ["/bin/bash", str(SCRIPT)],
            env={**os.environ, "HOME": str(self.home)},
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def archives(self):
        return sorted(self.backups.glob("os_bootstrap_*.zip"))

    def test_content_changes_missing_sources_and_retention(self):
        self.run_backup()
        self.assertFalse(self.backups.exists())
        (self.home / ".ssh").mkdir()
        (self.home / ".ssh" / "key with spaces").write_text("secret")
        (self.home / ".pi" / ".nested").mkdir(parents=True)
        (self.home / ".pi" / ".nested" / "config").write_text("pi")
        (self.home / ".gitconfig").write_text("git")
        (self.home / ".zsh_history").write_text("history")
        (self.home / ".zshrc.work").write_text("work")
        (self.home / ".zshrc").write_text("not included")
        (self.home / ".pi" / "external").symlink_to(self.home / ".zshrc")
        (self.home / ".pi" / "outside-dir").symlink_to(
            self.home / ".ssh", target_is_directory=True
        )
        self.run_backup()
        self.assertEqual(len(self.archives()), 1)
        with zipfile.ZipFile(self.archives()[0]) as archive:
            self.assertEqual(
                set(archive.namelist()),
                {
                    ".ssh/",
                    ".ssh/key with spaces",
                    ".pi/",
                    ".pi/.nested/",
                    ".pi/.nested/config",
                    ".pi/external",
                    ".pi/outside-dir",
                    ".gitconfig",
                    ".zsh_history",
                    ".zshrc.work",
                },
            )
            self.assertEqual(
                archive.read(".pi/external"), os.fsencode(self.home / ".zshrc")
            )
            self.assertEqual(archive.read(".ssh/key with spaces"), b"secret")
        self.run_backup()
        (self.home / ".zshrc").write_text("still excluded")
        self.run_backup()
        self.assertEqual(len(self.archives()), 1)
        for i in range(6):
            (self.home / ".pi" / ".nested" / "config").write_text(str(i))
            self.run_backup()
        self.assertEqual(len(self.archives()), 5)
        (self.home / ".gitconfig").unlink()
        self.run_backup()
        with zipfile.ZipFile(self.archives()[-1]) as archive:
            self.assertNotIn(".gitconfig", archive.namelist())
        self.assertEqual(len(self.archives()), 5)
        # Missing last successful archive must not suppress a replacement.
        state = json.loads(self.state.read_text())
        (self.backups / state["archive"]).unlink()
        self.run_backup()
        self.assertTrue(
            (self.backups / json.loads(self.state.read_text())["archive"]).exists()
        )

    def test_all_missing_preserves_previous_backup(self):
        source = self.home / ".gitconfig"
        source.write_text("first")
        self.run_backup()
        old_state = self.state.read_text()
        source.unlink()
        self.run_backup()
        self.assertEqual(self.state.read_text(), old_state)
        self.assertEqual(len(self.archives()), 1)

    def test_error_does_not_commit_state_or_archive(self):
        (self.home / ".gitconfig").write_text("first")
        self.run_backup()
        old_state = self.state.read_text()
        os.mkfifo(self.home / ".zsh_history")
        self.run_backup(success=False)
        self.assertEqual(self.state.read_text(), old_state)
        self.assertEqual(len(self.archives()), 1)
        self.assertEqual(list(self.backups.glob(".backup-*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
