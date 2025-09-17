#!/bin/sh
# install-helm-apk.sh — Instala Helm en Alpine usando apk
# Uso:
#   chmod +x install-helm-apk.sh
#   ./install-helm-apk.sh

apk add --no-cache bash curl tar openssl
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
