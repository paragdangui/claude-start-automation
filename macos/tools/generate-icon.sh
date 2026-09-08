#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swift -module-cache-path "$PWD/build/ModuleCache" tools/generate-icon.swift "$PWD/build/AppIcon.iconset"
# ICNS PNG representations, including Retina sizes.
python3 - <<'PY'
from pathlib import Path
import struct
root = Path('build/AppIcon.iconset')
entries = [('icp4','icon_16x16'),('icp5','icon_32x32'),('icp6','icon_32x32@2x'),('ic07','icon_128x128'),('ic08','icon_256x256'),('ic09','icon_512x512'),('ic10','icon_512x512@2x'),('ic11','icon_16x16@2x'),('ic12','icon_32x32@2x'),('ic13','icon_128x128@2x'),('ic14','icon_256x256@2x')]
chunks = []
for kind, name in entries:
    data = (root / (name + '.png')).read_bytes()
    chunks.append(kind.encode() + struct.pack('>I', len(data) + 8) + data)
payload = b''.join(chunks)
Path('GreetingScheduler/Resources/AppIcon.icns').write_bytes(b'icns' + struct.pack('>I', len(payload) + 8) + payload)
PY
