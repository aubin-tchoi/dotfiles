import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles tests ")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.repo = self.base / "repository with spaces"
        shutil.copytree(ROOT, self.repo, ignore=shutil.ignore_patterns(".git", "__pycache__", ".idea", "*.local", "*.rayconfig", ".env*", "*.db*", "*.backup*"))
        self.target = self.base / "new machine"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.state = self.base / "state"
        self.state.mkdir()
        self.env = {**os.environ, "PATH": f"{self.bin}:/usr/bin:/bin", "DOTFILES_TARGET_DIR": str(self.target),
                    "TEST_STATE": str(self.state), "TEST_PLATFORM": "Darwin", "PYTHONDONTWRITEBYTECODE": "1"}
        for name in ("brew", "git", "uname", "xcode-select", "npm", "pipx", "sudo", "dpkg-query", "defaults", "curl", "gitleaks"):
            fixture = str(ROOT / "tests/fake_command.py")
            self.stub(name, f'#!{sys.executable}\n__file__ = {fixture!r}\nexec(compile(open(__file__).read(), __file__, "exec"))\n')
        (self.bin / "python3").symlink_to(sys.executable)
        for name in ("bat", "direnv", "fzf", "gh", "git-lfs", "htop", "jq", "rg", "tmux", "tree", "diff-so-fancy"):
            self.stub(name)
        self.stub("zsh", f'#!/bin/bash\n[[ "$1" == -n ]] || exit 98\nexec {shutil.which("zsh")} "$@"\n')

    def stub(self, name, content="#!/bin/bash\nexit 0\n"):
        file = self.bin / name
        file.write_text(content)
        file.chmod(0o755)

    def run_script(self, script, *args, success=True, env=None):
        result = subprocess.run(["/bin/bash", str(self.repo / script), *map(str, args)], env=env or self.env,
                                cwd=self.repo, capture_output=True, text=True, timeout=45)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def calls(self):
        file = self.state / "calls"
        return [json.loads(line) for line in file.read_text().splitlines()] if file.exists() else []

    def snapshot(self):
        return {str(p.relative_to(self.target)): (os.readlink(p) if p.is_symlink() else p.read_bytes())
                for p in self.target.rglob("*") if p.is_file() or p.is_symlink()}

    def preferences(self, *args, success=True):
        result = subprocess.run([sys.executable, str(self.repo / "scripts/macos-defaults.py"), *map(str, args)],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_links_preserve_existing_files_broken_links_and_app_state(self):
        app = self.target / ".config/kitty"
        app.mkdir(parents=True)
        (app / "kitty.conf").write_text("my original settings")
        (app / "cache.db").write_text("app state")
        (self.target / ".gitconfig").symlink_to("missing")
        self.run_script("scripts/link.sh")
        backups = list(app.glob("kitty.conf.backup.*"))
        self.assertEqual(backups[0].read_text(), "my original settings")
        self.assertEqual((app / "cache.db").read_text(), "app state")
        self.assertEqual(os.readlink(next(self.target.glob(".gitconfig.backup.*"))), "missing")
        native = self.target / "Library/Application Support/com.mitchellh.ghostty/config"
        self.assertTrue(native.samefile(self.repo / "config/ghostty/config"))
        before = self.snapshot()
        self.run_script("scripts/link.sh")
        self.assertEqual(self.snapshot(), before)
        # Equivalent relative links are already correct.
        (self.target / ".zshrc").unlink()
        (self.target / ".zshrc").symlink_to(os.path.relpath(self.repo / "zshrc", self.target))
        self.run_script("scripts/link.sh")
        self.assertFalse(list(self.target.glob(".zshrc.backup.*")))

    def test_missing_source_fails_before_any_link(self):
        (self.repo / "config/zed/keymap.json").unlink()
        self.run_script("scripts/link.sh", success=False)
        self.assertFalse(self.target.exists())

    def test_core_install_and_rerun_skip_installers(self):
        self.run_script("install.sh")
        self.assertTrue((self.state / "Brewfile").exists())
        self.assertFalse((self.state / "Brewfile.full").exists())
        before = self.snapshot()
        (self.state / "calls").unlink()
        self.run_script("install.sh")
        self.assertEqual(self.snapshot(), before)
        calls = self.calls()
        self.assertFalse(any(c[:3] == ["brew", "bundle", "install"] or c[:2] == ["git", "clone"] or c[0] == "npm" for c in calls))
        self.assertEqual((self.state / "runtimes").read_text(), "install\n")
        (self.state / "calls").unlink()
        self.run_script("install.sh", "--check")
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(any(c[0] in ("git", "sudo", "defaults", "npm") for c in self.calls()))

    def test_full_install_preserves_custom_hooks(self):
        self.env["TEST_HOOKS"] = "custom-hooks"
        self.run_script("install.sh", "--full")
        self.assertTrue((self.state / "Brewfile.full").exists())
        self.assertFalse((self.state / "hooks").exists())

    def test_failed_package_install_stops_before_linking_and_can_resume(self):
        self.env["TEST_FAIL_BREW"] = "1"
        self.run_script("install.sh", success=False)
        self.assertFalse(self.target.exists())
        self.assertFalse(any(c[:2] == ["git", "clone"] for c in self.calls()))
        del self.env["TEST_FAIL_BREW"]
        self.run_script("install.sh")

    def test_interrupted_plugin_clone_can_resume(self):
        self.env["TEST_FAIL_CLONE"] = "zsh-autosuggestions"
        self.run_script("install.sh", success=False)
        self.assertFalse((self.target / ".zshrc").exists())
        self.assertFalse(list(self.target.rglob("*.install.*")))
        del self.env["TEST_FAIL_CLONE"]
        self.run_script("install.sh")

    def test_check_empty_machine_and_invalid_flags_never_install(self):
        self.run_script("install.sh", "--check", success=False)
        self.assertFalse(self.target.exists())
        self.assertFalse(any(c[0] in ("git", "sudo", "npm", "defaults") for c in self.calls()))
        for flags in (("--unknown",), ("--check", "--macos-defaults"), ("--restore-private",), ("--check", "--link-only")):
            self.run_script("install.sh", *flags, success=False)
        self.assertFalse(self.target.exists())

    def test_ubuntu_full_and_rerun(self):
        self.env["TEST_PLATFORM"] = "Linux"
        release = self.base / "os-release"
        release.write_text('ID=ubuntu\nVERSION_ID="24.04"\n')
        self.env["DOTFILES_OS_RELEASE_FILE"] = str(release)
        (self.bin / "bat").unlink()
        (self.bin / "diff-so-fancy").unlink()
        self.stub("batcat")
        self.run_script("install.sh", "--full")
        self.assertTrue((self.target / ".local/bin/bat").is_symlink())
        self.assertTrue((self.target / ".local/bin/diff-so-fancy").exists())
        self.assertTrue((self.target / ".config/terminator/config").is_symlink())
        self.assertFalse((self.target / "Library").exists())
        self.assertIn("protobuf-compiler", (self.state / "packages").read_text())
        (self.state / "calls").unlink()
        self.run_script("install.sh", "--full")
        self.assertFalse(any(c[0] in ("sudo", "npm", "pipx") or c[:2] == ["git", "clone"] for c in self.calls()))

    def test_unsupported_linux_fails_before_installation(self):
        self.env["TEST_PLATFORM"] = "Linux"
        release = self.base / "os-release"
        release.write_text("ID=fedora\n")
        self.env["DOTFILES_OS_RELEASE_FILE"] = str(release)
        self.run_script("install.sh", success=False)
        self.assertFalse(self.target.exists())
        self.assertFalse(any(c[0] == "sudo" for c in self.calls()))

    def test_private_restore_allowlist_permissions_backups_and_rerun(self):
        private = self.base / "private backup"
        private.mkdir()
        (private / ".zshrc.local").write_text("new private overrides")
        (private / "raycast.rayconfig").write_bytes(b"opaque private export")
        (private / "unrelated.txt").write_text("leave this alone")
        self.target.mkdir()
        (self.target / ".zshrc.local").write_text("old private overrides")
        self.run_script("scripts/restore-private.sh", private)
        restored = self.target / ".zshrc.local"
        self.assertEqual(restored.stat().st_mode & 0o777, 0o600)
        self.assertEqual(next(self.target.glob(".zshrc.local.backup.*")).read_text(), "old private overrides")
        self.assertEqual((self.target / ".local/state/dotfiles/private").stat().st_mode & 0o777, 0o700)
        self.assertFalse((self.target / "unrelated.txt").exists())
        before = self.snapshot()
        self.run_script("scripts/restore-private.sh", private)
        self.assertEqual(self.snapshot(), before)
        self.run_script("scripts/restore-private.sh", self.repo, success=False)

    def test_private_restore_rejects_symlink_before_changing_other_files(self):
        private = self.base / "backup"
        private.mkdir()
        (private / ".zshrc.local").write_text("example override")
        (private / ".gitconfig.local").symlink_to(private / ".zshrc.local")
        self.run_script("scripts/restore-private.sh", private, success=False)
        self.assertFalse(self.target.exists())

    def test_preferences_apply_rerun_and_restore_exact_original_values(self):
        original = {"NSGlobalDomain/KeyRepeat": ["integer", 6], "com.apple.dock/autohide": ["boolean", False],
                    "unrelated.app/setting": ["string", "unchanged"]}
        database = self.state / "defaults.json"
        database.write_text(json.dumps(original))
        self.preferences("apply")
        backups = list((self.target / ".local/state/dotfiles/macos").glob("*.json"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(database.read_text())["NSGlobalDomain/KeyRepeat"], ["float", 2.0])
        self.preferences("apply")
        self.assertEqual(len(list(backups[0].parent.glob("*.json"))), 1)
        self.preferences("restore", backups[0])
        self.assertEqual(json.loads(database.read_text()), original)
        self.preferences("restore", backups[0])
        self.assertEqual(json.loads(database.read_text()), original)

    def test_preferences_restore_rejects_unlisted_keys_before_writing(self):
        backup = self.base / "bad-backup.json"
        backup.write_text(json.dumps([{"domain": "unlisted", "key": "setting", "present": False}]))
        self.preferences("restore", backup, success=False)
        self.assertFalse(any(c[0] == "defaults" for c in self.calls()))

    def test_private_restore_rejects_destination_directory_inside_repo(self):
        private = self.base / "backup"
        private.mkdir()
        (private / "raycast.rayconfig").write_bytes(b"opaque private export")
        self.target.mkdir()
        (self.target / ".local").symlink_to(self.repo, target_is_directory=True)
        self.run_script("scripts/restore-private.sh", private, success=False)
        self.assertFalse((self.repo / "state").exists())

    def test_secret_scan_selects_staged_diff_or_head_history(self):
        self.run_script("scripts/check-secrets.sh", "--staged")
        self.assertIn("--staged", self.calls()[-1])
        self.assertIn("--pre-commit", self.calls()[-1])
        self.run_script("scripts/check-secrets.sh")
        self.assertIn("--log-opts=HEAD", self.calls()[-1])
        self.assertIn("--redact", self.calls()[-1])

    def test_scanner_download_verifies_checksum_before_installing(self):
        (self.bin / "gitleaks").unlink()
        downloads = self.base / "downloads"
        downloads.mkdir()
        self.env["TEST_DOWNLOADS"] = str(downloads)
        archive = downloads / "gitleaks_8.30.1_darwin_arm64.tar.gz"
        with tarfile.open(archive, "w:gz") as bundle:
            payload = b"#!/bin/bash\nexit 0\n"
            member = tarfile.TarInfo("gitleaks")
            member.size = len(payload)
            bundle.addfile(member, io.BytesIO(payload))
        checksums = downloads / "gitleaks_8.30.1_checksums.txt"
        checksums.write_text("0" * 64 + "  " + archive.name + "\n")
        self.run_script("scripts/install-gitleaks.sh", success=False)
        self.assertFalse((self.target / ".local/bin/gitleaks").exists())
        checksums.write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n")
        self.run_script("scripts/install-gitleaks.sh")
        self.assertTrue(os.access(self.target / ".local/bin/gitleaks", os.X_OK))

    def test_jsonc_keeps_comment_markers_inside_strings(self):
        spec = importlib.util.spec_from_file_location("check_json", ROOT / "scripts/check-json.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.parse_jsonc('{/* comment */ "url": "https://example.test/*x*/,}", // comment\n "list": [1,],}'),
                         {"url": "https://example.test/*x*/,}", "list": [1]})
        with self.assertRaises(json.JSONDecodeError):
            module.parse_jsonc('{"broken": }')


if __name__ == "__main__":
    unittest.main()
