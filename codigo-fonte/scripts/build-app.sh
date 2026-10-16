#!/bin/zsh
# Compila o Teleprompter Ethos e monta "dist/Teleprompter Ethos.app".
# Requer apenas as Command Line Tools da Apple (xcode-select --install). Não precisa de conta paga.
# Opções: --install (copia para ~/Applications)  --universal (roda em Mac com chip Apple e com Intel)
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="Teleprompter Ethos"
# Compila fora do iCloud Drive (mais rápido e evita atributos que atrapalham a assinatura).
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/TeleprompterEthos-build}"
STAGE="$BUILD_DIR/stage"
APP="$STAGE/$APP_NAME.app"

INSTALL=0; UNIVERSAL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --universal) UNIVERSAL=1 ;;
  esac
done

if (( UNIVERSAL )); then
  echo "▸ Compilando (release) para chip Apple e para Intel…"
  for ARCH in arm64 x86_64; do
    swift build -c release --scratch-path "$BUILD_DIR/$ARCH" --triple "$ARCH-apple-macosx14.0" --product TeleprompterEthos
  done
  BIN="$BUILD_DIR/TeleprompterEthos-universal"
  lipo -create -output "$BIN" \
    "$BUILD_DIR/arm64/arm64-apple-macosx/release/TeleprompterEthos" \
    "$BUILD_DIR/x86_64/x86_64-apple-macosx/release/TeleprompterEthos"
else
  echo "▸ Compilando (release)…"
  swift build -c release --scratch-path "$BUILD_DIR" --product TeleprompterEthos
  BIN="$(swift build -c release --scratch-path "$BUILD_DIR" --show-bin-path)/TeleprompterEthos"
fi

echo "▸ Montando o pacote .app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TeleprompterEthos"
cp Support/Info.plist "$APP/Contents/Info.plist"

if [[ ! -f Support/AppIcon.icns ]]; then
  echo "▸ Gerando ícone…"
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  rm -rf "$ICONSET"
  swift scripts/make-icon.swift "$ICONSET"
  iconutil -c icns "$ICONSET" -o Support/AppIcon.icns
fi
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Assinando localmente (ad hoc, gratuito)…"
xattr -cr "$APP"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

mkdir -p dist
rm -rf "dist/$APP_NAME.app"
ditto "$APP" "dist/$APP_NAME.app"
echo "✓ Pronto: $ROOT/dist/$APP_NAME.app"

if (( INSTALL )); then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APP_NAME.app"
  ditto "$APP" "$HOME/Applications/$APP_NAME.app"
  echo "✓ Instalado em $HOME/Applications/$APP_NAME.app"
fi
