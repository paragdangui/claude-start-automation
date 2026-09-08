#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
python3 tests/test_runners.py
xcrun swiftc -swift-version 5 -module-cache-path "$PWD/build/ModuleCache" GreetingScheduler/SettingsStore.swift GreetingScheduler/ProcessRunner.swift GreetingScheduler/LaunchAgentManager.swift tests/CoreTests.swift -o build/core-tests
build/core-tests "$PWD/GreetingScheduler/Resources/runner.sh"
