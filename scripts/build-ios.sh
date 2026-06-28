#!/usr/bin/env bash
# Gera o app iOS do Caixa Posto Janjão (requer macOS + Xcode).
#
# Pré-requisitos:
#   - macOS com Xcode 15+ e CocoaPods
#   - Conta Apple Developer (para instalar em iPhone/iPad)
#   - flet instalado: pip install "flet>=0.85.3"
#
# Uso:
#   ./scripts/build-ios.sh simulator          # teste no Simulador (sem assinatura)
#   ./scripts/build-ios.sh ipa                  # .ipa para dispositivo (exige assinatura)
#
# Configure team_id e provisioning_profile em pyproject.toml ([tool.flet.ios])
# ou passe na linha de comando (ver README).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Erro: build iOS só funciona no macOS (Xcode)." >&2
  exit 1
fi

TARGET="${1:-simulator}"

case "$TARGET" in
  simulator)
    echo ">> Build para iOS Simulator..."
    flet build ios-simulator
    echo ""
    echo "Pronto. Abra o Simulator e instale:"
    echo "  build/ios-simulator/Runner.app"
    ;;
  ipa)
    echo ">> Build IPA (dispositivo físico)..."
    flet build ipa
    echo ""
    echo "Pronto. Arquivo gerado em build/ipa/ (se assinatura configurada)."
    ;;
  *)
    echo "Uso: $0 {simulator|ipa}" >&2
    exit 1
    ;;
esac
