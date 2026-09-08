"""Opt-in real launchd test with an isolated label and a local stub. No service calls."""
import datetime, json, os, pathlib, plistlib, subprocess, tempfile, time
root = pathlib.Path(tempfile.mkdtemp(prefix='greeting launchd test '))
label = f'local.GreetingScheduler.test.{os.getpid()}'
domain = f'gui/{os.getuid()}'
source = pathlib.Path(__file__).resolve().parents[1] / 'GreetingScheduler/Resources/runner.sh'
runner = root/'runner.sh'
runner.write_bytes(source.read_bytes())
stub = root/'stub cli'
stub.write_text('#!/bin/bash\necho launchd-stub-success\n')
stub.chmod(0o700)
when = datetime.datetime.now() + datetime.timedelta(minutes=1)
plist = root/'test.plist'
plist.write_bytes(plistlib.dumps({'Label': label, 'ProgramArguments': ['/bin/bash', str(runner), 'claude', str(stub), str(root)], 'RunAtLoad': False, 'StartCalendarInterval': {'Hour': when.hour, 'Minute': when.minute}, 'EnvironmentVariables': {'HOME': str(pathlib.Path.home()), 'PATH': '/usr/bin:/bin:/usr/sbin:/sbin'}, 'StandardErrorPath': str(root/'launchd.log')}))
def ctl(*args): return subprocess.run(['/bin/launchctl', *args], capture_output=True, text=True)
try:
    result = ctl('bootstrap', domain, str(plist))
    assert result.returncode == 0, result.stderr
    record = root/'status/claude.json'
    assert not record.exists(), 'Bootstrap unexpectedly ran greeting'
    print(f'Isolated job loaded; waiting for calendar minute {when:%H:%M}.', flush=True)
    deadline = time.monotonic() + 90
    while not record.exists() and time.monotonic() < deadline: time.sleep(.5)
    while time.monotonic() < deadline:
        if record.exists() and json.loads(record.read_text())['exitCode'] is not None: break
        time.sleep(.1)
    if not record.exists():
        print(ctl('print', f'{domain}/{label}').stdout)
        print((root/'launchd.log').read_text() if (root/'launchd.log').exists() else 'No launchd log')
        raise AssertionError('Calendar job produced no status')
    assert json.loads(record.read_text())['exitCode'] == 0
    assert 'launchd-stub-success' in (root/'logs/claude.log').read_text()
    print('PASS: bootstrap sent no greeting; calendar job ran local stub successfully.', flush=True)
finally:
    ctl('bootout', f'{domain}/{label}')
    import shutil
    shutil.rmtree(root)
