#!/bin/zsh
# Executa os testes do núcleo (rolagem, persistência, .txt, telas, atalhos).
# Funciona só com as Command Line Tools (sem Xcode). No Xcode, use Product ▸ Test.
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/TeleprompterEthos-build}"
DEV=$(xcode-select -p)
ARGS=()
# Com as Command Line Tools, o framework Swift Testing fica fora do caminho padrão.
for F in "$DEV/Library/Developer/Frameworks"; do
  [[ -d "$F" ]] && ARGS+=(-Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F")
done
L="$DEV/Library/Developer/usr/lib"
[[ -d "$L" ]] && ARGS+=(-Xlinker -rpath -Xlinker "$L")
swift test --scratch-path "$BUILD_DIR" "${ARGS[@]}"
