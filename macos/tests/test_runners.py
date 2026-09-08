import json, os, pathlib, subprocess, tempfile, time, unittest
RUNNER = pathlib.Path(__file__).resolve().parents[1] / 'GreetingScheduler/Resources/runner.sh'
class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='greeting tests ')
        self.root = pathlib.Path(self.temp.name)
        self.cli = self.root / 'stub cli'
        self.cli.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "${0}.args"\necho stub-output\nsleep "${STUB_DELAY:-0}"\nexit "${STUB_EXIT:-0}"\n')
        self.cli.chmod(0o700)
    def tearDown(self): self.temp.cleanup()
    def run_cli(self, provider='claude', **env):
        return subprocess.run(['/bin/bash', str(RUNNER), provider, str(self.cli), str(self.root)], env=dict(os.environ, **env)).returncode
    def record(self, provider='claude'): return json.loads((self.root / f'status/{provider}.json').read_text())
    def test_success_and_flags(self):
        self.assertEqual(self.run_cli(), 0)
        self.assertEqual(self.record()['exitCode'], 0)
        self.assertEqual(pathlib.Path(str(self.cli)+'.args').read_text().splitlines(), ['--print','Good morning','--no-session-persistence','--tools','','--max-budget-usd','0.05'])
        self.assertIn('stub-output', (self.root/'logs/claude.log').read_text())
    def test_codex_failure(self):
        self.assertEqual(self.run_cli('codex', STUB_EXIT='9'), 9)
        self.assertEqual(self.record('codex')['exitCode'], 9)
        args = pathlib.Path(str(self.cli)+'.args').read_text().splitlines()
        self.assertEqual(args[:5], ['exec','--ephemeral','--skip-git-repo-check','--sandbox','read-only'])
    def test_cli_exit_75_is_failure(self):
        result = subprocess.run(['/bin/bash', str(RUNNER), 'claude', str(self.cli), str(self.root)], env=dict(os.environ, STUB_EXIT='75'), capture_output=True, text=True)
        self.assertEqual(result.returncode, 75)
        self.assertNotIn('GREETING_SCHEDULER_ALREADY_RUNNING', result.stdout)
        self.assertEqual(self.record()['exitCode'], 75)
    def test_overlap(self):
        first = subprocess.Popen(['/bin/bash', str(RUNNER), 'claude', str(self.cli), str(self.root)], env=dict(os.environ, STUB_DELAY='2'))
        try:
            for _ in range(100):
                if (self.root/'status/claude.json').exists(): break
                time.sleep(.02)
            self.assertEqual(self.run_cli(), 75)
            self.assertEqual(first.wait(timeout=5), 0)
            self.assertEqual(self.record()['exitCode'], 0)
        finally:
            if first.poll() is None: first.kill(); first.wait()
    def test_stale_lock(self):
        (self.root/'status').mkdir()
        (self.root/'status/claude.lock').write_text('99999999\n')
        self.assertEqual(self.run_cli(), 0)
    def test_missing_executable(self):
        self.cli.unlink()
        self.assertEqual(self.run_cli(), 127)
        self.assertEqual(self.record()['exitCode'], 127)
if __name__ == '__main__': unittest.main()
