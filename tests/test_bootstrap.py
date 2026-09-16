"""Offline checks: writes are confined to temporary homes."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Match scripts/lib.sh: the system interpreter is the one a fresh host has.
PYTHON = '/usr/bin/python3'


class DeployTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.src = self.home / 'source'
        self.src.write_text('new\n')
        self.dst = self.home / '.config/app/settings'
        self.env = dict(os.environ, HOME=str(self.home))

    def deploy(self, *args, success=True):
        result = subprocess.run(
            [PYTHON, str(ROOT / 'scripts/deploy-config.py'), str(self.src), str(self.dst), *args],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result.stdout

    def test_dry_run_does_not_create_directories(self):
        self.deploy()
        self.assertFalse(self.dst.parent.exists())

    def test_repeat_apply_is_noop(self):
        self.deploy('--mode', 'apply')
        before = self.dst.stat().st_mtime_ns
        self.assertIn('OK', self.deploy('--mode', 'apply'))
        self.assertEqual(before, self.dst.stat().st_mtime_ns)

    def test_conflict_preserved_then_backed_up(self):
        self.dst.parent.mkdir(parents=True)
        self.dst.write_text('old\n')
        self.assertIn('PRESERVE', self.deploy('--mode', 'apply'))
        self.assertEqual(self.dst.read_text(), 'old\n')
        self.deploy('--replace')
        self.assertFalse((self.home / '.local').exists())
        self.deploy('--mode', 'apply', '--replace')
        backups = list((self.home / '.local/state/midgard/backups').rglob('settings'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'old\n')
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.dst.read_text(), 'new\n')

    def test_diff_shows_plain_text_but_never_json(self):
        self.dst.parent.mkdir(parents=True)
        self.dst.write_text('old\n')
        self.assertNotIn('-old', self.deploy())
        out = self.deploy('--diff')
        self.assertIn('-old', out)
        self.assertIn('+new', out)
        self.dst.write_text(json.dumps({'env': {'SECRET': 'local-only'}}))
        self.src.write_text(json.dumps({'theme': 'dark'}))
        out = self.deploy('--diff', '--merge-json')
        self.assertIn('PRESERVE', out)
        self.assertNotIn('local-only', out)

    def test_errors_are_messages_not_tracebacks(self):
        self.dst.parent.mkdir(parents=True)
        self.dst.write_text('not json')
        self.src.write_text('{}')
        result = subprocess.run([PYTHON, str(ROOT / 'scripts/deploy-config.py'), str(self.src), str(self.dst),
                                 '--merge-json'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('Traceback', result.stderr)
        outside = Path(tempfile.mkdtemp()) / 'settings'
        self.addCleanup(outside.unlink)
        outside.write_text('old\n')
        result = subprocess.run([PYTHON, str(ROOT / 'scripts/deploy-config.py'), str(self.src), str(outside),
                                 '--mode', 'apply', '--replace'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(outside.read_text(), 'old\n')

    def test_create_only_seeds_private_file_and_never_replaces(self):
        self.deploy('--mode', 'apply', '--create-only')
        self.assertEqual(self.dst.read_text(), 'new\n')
        self.assertEqual(self.dst.stat().st_mode & 0o777, 0o600)
        self.dst.write_text('app rewrote this\n')
        self.assertIn('KEEP', self.deploy('--mode', 'apply', '--replace', '--create-only'))
        self.assertEqual(self.dst.read_text(), 'app rewrote this\n')
        self.assertFalse((self.home / '.local/state/midgard/backups').exists())

    def test_symlink_refused_even_with_replace(self):
        self.dst.parent.mkdir(parents=True)
        self.dst.symlink_to(self.src)
        self.deploy('--mode', 'apply', '--replace', success=False)
        self.assertEqual(self.src.read_text(), 'new\n')

    def test_json_preserves_permissions_and_other_hooks(self):
        original = {'permissions': {'deny': ['Bash(rm *)']},
                    'hooks': {'PreToolUse': [{'matcher': 'Read', 'hooks': []}]},
                    'env': {'PRIVATE_SETTING': 'local-only'}}
        self.dst.parent.mkdir(parents=True)
        self.dst.write_text(json.dumps(original))
        self.dst.chmod(0o600)
        self.src.write_bytes((ROOT / 'config/claude/settings.json').read_bytes())
        self.deploy('--mode', 'apply', '--replace', '--merge-json')
        result = json.loads(self.dst.read_text())
        self.assertEqual(self.dst.stat().st_mode & 0o777, 0o600)
        self.assertEqual(result['permissions'], original['permissions'])
        self.assertEqual(result['env'], original['env'])
        self.assertEqual(result['hooks']['PreToolUse'][0], original['hooks']['PreToolUse'][0])
        self.assertEqual(len(result['hooks']['PreToolUse']), 2)
        before = self.dst.read_bytes()
        self.deploy('--mode', 'apply', '--replace', '--merge-json')
        self.assertEqual(before, self.dst.read_bytes())


class HookTests(unittest.TestCase):
    def test_push_and_merge_require_confirmation(self):
        for command in ['git push', 'git -C /tmp/repo push origin dev',
                        'cd /tmp && git push', 'git merge feature',
                        'gh pr merge 123', 'gh api repos/example/repo/pulls/1/merge']:
            with self.subTest(command=command):
                result = subprocess.run(['bash', str(ROOT / 'config/claude/hooks/confirm-push-merge.sh')],
                    input=json.dumps({'tool_input': {'command': command}}),
                    capture_output=True, text=True, check=True)
                self.assertEqual(json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'], 'ask')

    def test_read_only_git_command(self):
        result = subprocess.run(['bash', str(ROOT / 'config/claude/hooks/confirm-push-merge.sh')],
            input=json.dumps({'tool_input': {'command': 'git status'}}),
            capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout, '')


class BootstrapTests(unittest.TestCase):
    def test_fresh_home_dry_run_is_read_only(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = dict(os.environ, HOME=directory, PATH='/usr/bin:/bin')
            result = subprocess.run(['bash', str(ROOT / 'bootstrap.sh'), '--dry-run'],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            node = tomllib.loads((ROOT / 'config/mise/config.toml').read_text())['tools']['node']
            self.assertIn(f'mise install node@{node}', result.stdout)
            self.assertIn('CREATE', result.stdout)
            self.assertEqual(list(home.iterdir()), [])

    def test_configuration_apply_twice(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = dict(os.environ, HOME=directory, PATH='/usr/bin:/bin')
            command = ['bash', str(ROOT / 'bootstrap.sh'), '--apply', '--only', 'fish,tmux,dotfiles']
            first = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            logs = home / '.local/state/midgard/logs'

            def snapshot():
                return {str(p.relative_to(home)): (p.read_bytes(), p.stat().st_mtime_ns)
                        for p in home.rglob('*') if p.is_file() and logs not in p.parents}
            before = snapshot()
            second = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(before, snapshot())
            self.assertFalse((home / '.local/state/midgard/backups').exists())
            self.assertEqual(len(list(logs.iterdir())), 2)
            self.assertEqual(logs.stat().st_mode & 0o777, 0o700)

    def test_invalid_step_stops_before_changes(self):
        result = subprocess.run(['bash', str(ROOT / 'bootstrap.sh'), '--apply', '--only', 'system,typo'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertNotIn('apt-get', result.stdout)


if __name__ == '__main__':
    unittest.main()
