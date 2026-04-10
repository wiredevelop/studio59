#!/usr/bin/env bash
set -euo pipefail

APP_NAME="studio59"
OUT_DIR="backend/public/app"
OUT_FILE="$OUT_DIR/${APP_NAME}.aab"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Erro: flutter nao encontrado no PATH."
  exit 1
fi

if [[ ! -f pubspec.yaml ]]; then
  echo "Erro: pubspec.yaml nao encontrado. Execute na raiz do projeto."
  exit 1
fi

KEY_PROPS="android/key.properties"
if [[ ! -f "$KEY_PROPS" ]]; then
  if [[ -n "${ANDROID_KEYSTORE_PATH:-}" && -n "${ANDROID_KEYSTORE_PASSWORD:-}" && -n "${ANDROID_KEY_ALIAS:-}" && -n "${ANDROID_KEY_PASSWORD:-}" ]]; then
    cat > "$KEY_PROPS" <<EOF
storeFile=${ANDROID_KEYSTORE_PATH}
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
keyPassword=${ANDROID_KEY_PASSWORD}
EOF
    echo "Criado $KEY_PROPS a partir de variaveis de ambiente."
  else
    echo "Erro: android/key.properties nao encontrado."
    echo "Crie o arquivo com:"
    echo "  storeFile=/caminho/para/keystore.jks"
    echo "  storePassword=..."
    echo "  keyAlias=..."
    echo "  keyPassword=..."
    echo "Ou defina as variaveis: ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD"
    exit 1
  fi
fi

# Bump build number no pubspec.yaml (versao: X.Y.Z+N)
python3 - <<'PY'
import re
from pathlib import Path
path = Path('pubspec.yaml')
text = path.read_text()
match = re.search(r'^(version:\s*)(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$', text, re.M)
if not match:
    raise SystemExit('Erro: campo version nao encontrado no pubspec.yaml')
full, base, build = match.group(1), match.group(2), match.group(3)
old_build = int(build or 0)
new_build = old_build + 1
old_version = f"{base}+{old_build}"
new_version = f"{base}+{new_build}"
text = re.sub(r'^(version:\s*)(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$', f"{full}{new_version}", text, flags=re.M)
path.write_text(text)
print(f"Bumped pubspec.yaml version: {old_version} -> {new_version}")
PY

flutter pub get

TARGET_PLATFORMS="${TARGET_PLATFORMS:-android-arm,android-arm64,android-x64}"
flutter build appbundle --release --target-platform "$TARGET_PLATFORMS"

mkdir -p "$OUT_DIR"
cp -f build/app/outputs/bundle/release/app-release.aab "$OUT_FILE"

echo "AAB publicado em: $OUT_FILE"
