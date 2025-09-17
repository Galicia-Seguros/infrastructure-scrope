#!/bin/sh
# install-helm-apk.sh — Instala Helm en Alpine usando apk
# Uso:
#   chmod +x install-helm-apk.sh
#   ./install-helm-apk.sh

set -eu

echo "==> Instalando Helm con apk..."
# Idempotente: si ya está instalado, no falla
if apk info -e helm >/dev/null 2>&1; then
  echo "==> Helm ya está instalado: $(helm version --short || true)"
  exit 0
fi

# Actualiza índices y evita cache para mantener la imagen liviana
apk add --no-cache helm

echo "==> Verificación:"
helm version
