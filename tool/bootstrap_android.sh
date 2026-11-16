#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Generate only standard Flutter/Gradle infrastructure with the pinned SDK.
# All authored native code, manifests, backup rules and app build settings win.
if [ -f android/gradlew ] && [ -f android/settings.gradle.kts ]; then
  chmod +x android/gradlew
  exit 0
fi
seed=work/android-seed
if [ ! -f "$seed/android/gradlew" ]; then
  flutter create --no-pub --empty --platforms=android --org dk.ask --project-name nelko_p21_ask_mobile "$seed"
fi
python3 - <<'PY'
from pathlib import Path
import shutil
seed=Path('work/android-seed/android')
for source in seed.rglob('*'):
    relative=source.relative_to(seed)
    # Do not generate extra activities or manifests with debug INTERNET access.
    if '.gradle' in relative.parts or 'src' in relative.parts or relative.name=='local.properties':
        continue
    target=Path('android')/relative
    if source.is_dir():
        target.mkdir(parents=True,exist_ok=True)
    elif not target.exists():
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,target)
PY
chmod +x android/gradlew
