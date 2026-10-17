#!/usr/bin/env bash
# ==============================================================================
# Script de Verificação Pós-Instalação — Kubuntu 26.04 LTS
# Executa verificações de integridade e versões das ferramentas instaladas.
# Modo de leitura: não requer sudo nem faz alterações no sistema.
# ==============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

# Cores para o terminal
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

declare -i TOTAL_OK=0
declare -i TOTAL_WARN=0
declare -i TOTAL_FAIL=0

# Garante que caminhos comuns de usuário estão no PATH da sessão
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Carrega NVM se existir para testar node/npm
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh" --no-use >/dev/null 2>&1 || true
  nvm use default >/dev/null 2>&1 || true
fi

has() { command -v "$1" >/dev/null 2>&1; }

check_cmd() {
  local label="$1" cmd="$2" version_cmd="${3:-}"
  local version=""
  if has "$cmd"; then
    if [[ -n "$version_cmd" ]]; then
      version="$(eval "$version_cmd" 2>/dev/null | head -n 1 | tr -s ' ')"
    fi
    printf "  %b[OK]%b %-28s %b%s%b\n" "$GREEN" "$NC" "$label" "$BLUE" "${version:-instalado}" "$NC"
    ((TOTAL_OK++))
  else
    printf "  %b[FALHA]%b %-28s %bNão encontrado%b\n" "$RED" "$NC" "$label" "$RED" "$NC"
    ((TOTAL_FAIL++))
  fi
}

check_optional_cmd() {
  local label="$1" cmd="$2" version_cmd="${3:-}"
  local version=""
  if has "$cmd"; then
    if [[ -n "$version_cmd" ]]; then
      version="$(eval "$version_cmd" 2>/dev/null | head -n 1 | tr -s ' ')"
    fi
    printf "  %b[OK]%b %-28s %b%s%b\n" "$GREEN" "$NC" "$label" "$BLUE" "${version:-instalado}" "$NC"
    ((TOTAL_OK++))
  else
    printf "  %b[OPCIONAL]%b %-25s %bNão configurado / ausente%b\n" "$YELLOW" "$NC" "$label" "$YELLOW" "$NC"
    ((TOTAL_WARN++))
  fi
}

check_dpkg() {
  local label="$1" pkg="$2"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    local ver
    ver="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)"
    printf "  %b[OK]%b %-28s %b%s%b\n" "$GREEN" "$NC" "$label" "$BLUE" "$ver" "$NC"
    ((TOTAL_OK++))
  else
    printf "  %b[FALHA]%b %-28s %bPacote não instalado%b\n" "$RED" "$NC" "$label" "$RED" "$NC"
    ((TOTAL_FAIL++))
  fi
}

check_flatpak_app() {
  local label="$1" app_id="$2"
  if has flatpak && flatpak list --app | grep -Fq "$app_id"; then
    local ver
    ver="$(flatpak list --app --columns=application,version | grep "^${app_id}" | awk '{print $2}')"
    printf "  %b[OK]%b %-28s %bFlatpak: %s%b\n" "$GREEN" "$NC" "$label" "$BLUE" "${ver:-instalado}" "$NC"
    ((TOTAL_OK++))
  else
    printf "  %b[FALHA]%b %-28s %bFlatpak ausente%b\n" "$RED" "$NC" "$label" "$RED" "$NC"
    ((TOTAL_FAIL++))
  fi
}

section() {
  printf "\n%b=== %s ===%b\n" "$BOLD" "$1" "$NC"
}

main() {
  printf "\n%b========================================================%b\n" "$BOLD" "$NC"
  printf "%b   Auditoria de Instalação — Kubuntu 26.04 LTS          %b\n" "$BOLD" "$NC"
  printf "%b========================================================%b\n" "$BOLD" "$NC"

  section "Sistema e Ferramentas Base"
  check_cmd "Git" git "git --version"
  check_cmd "Git LFS" git-lfs "git-lfs --version"
  check_cmd "Curl" curl "curl --version | head -n1"
  check_cmd "Wget" wget "wget --version | head -n1"
  check_cmd "JQ" jq "jq --version"
  check_cmd "Unzip" unzip "unzip -v | head -n1"
  check_cmd "Rsync" rsync "rsync --version | head -n1"
  check_cmd "Build Essential (gcc)" gcc "gcc --version | head -n1"
  check_cmd "DKMS" dkms "dkms --version"

  section "Multimídia, Codecs e Documentos"
  check_cmd "FFmpeg" ffmpeg "ffmpeg -version | head -n1 | cut -d' ' -f1-3"
  check_cmd "VLC Media Player" vlc "vlc --version | head -n1"
  check_cmd "Okular (PDF)" okular "okular --version | head -n1"
  check_dpkg "Kubuntu Restricted Extras" kubuntu-restricted-extras

  section "Flatpak e Integração KDE"
  check_cmd "Flatpak CLI" flatpak "flatpak --version"
  check_dpkg "Discover Flatpak Backend" plasma-discover-backend-flatpak
  if has flatpak; then
    if flatpak remotes | grep -Fq "flathub"; then
      printf "  %b[OK]%b %-28s %bConfigurado%b\n" "$GREEN" "$NC" "Repositório Flathub" "$BLUE" "$NC"
      ((TOTAL_OK++))
    else
      printf "  %b[FALHA]%b %-28s %bFlathub ausente%b\n" "$RED" "$NC" "Repositório Flathub" "$RED" "$NC"
      ((TOTAL_FAIL++))
    fi
  fi
  check_flatpak_app "Chromium" org.chromium.Chromium
  check_flatpak_app "LibreWolf" io.gitlab.librewolf-community
  check_flatpak_app "DBeaver Community" io.dbeaver.DBeaverCommunity
  check_flatpak_app "Podman Desktop" io.podman_desktop.PodmanDesktop
  check_flatpak_app "RustDesk" com.rustdesk.RustDesk

  section "Acesso Remoto & Redes"
  check_optional_cmd "AnyDesk" anydesk "anydesk --version"
  check_cmd "OpenSSH Client" ssh "ssh -V"
  check_cmd "Nmap" nmap "nmap --version | head -n1"
  check_cmd "Btop" btop "btop --version | head -n1"

  section "Desenvolvimento: Linha de Comando e Editores"
  check_cmd "GitHub CLI" gh "gh --version | head -n1"
  check_cmd "VS Code" code "code --version | head -n1"

  section "Desenvolvimento: Python"
  check_cmd "Python 3" python3 "python3 --version"
  check_cmd "Pipx" pipx "pipx --version"
  check_cmd "UV (Package manager)" uv "uv --version"

  section "Desenvolvimento: Node.js (via NVM)"
  if [[ -d "$HOME/.nvm" ]]; then
    printf "  %b[OK]%b %-28s %bInstalado em ~/.nvm%b\n" "$GREEN" "$NC" "NVM Directory" "$BLUE" "$NC"
    ((TOTAL_OK++))
  else
    printf "  %b[FALHA]%b %-28s %b~/.nvm não encontrado%b\n" "$RED" "$NC" "NVM Directory" "$RED" "$NC"
    ((TOTAL_FAIL++))
  fi
  check_cmd "Node.js" node "node -v"
  check_cmd "NPM" npm "npm -v"

  section "Desenvolvimento: Java"
  check_cmd "Java Runtime (java)" java "java -version 2>&1 | head -n1"
  check_cmd "Java Compiler (javac)" javac "javac -version 2>&1 | head -n1"

  section "Contêineres (Podman)"
  check_cmd "Podman" podman "podman --version"
  check_cmd "Podman Compose" podman-compose "podman-compose --version | head -n1"
  check_cmd "Buildah" buildah "buildah --version"
  check_cmd "Skopeo" skopeo "skopeo --version"

  section "Ferramentas Específicas / Opcionais"
  check_optional_cmd "Antigravity CLI (agy)" agy "agy --version"
  check_optional_cmd "Scion Harness" scion "scion --version"

  # Resumo Final
  printf "\n%b=================== RESUMO DA AUDITORIA ===================%b\n" "$BOLD" "$NC"
  printf "  %bItens aprovados [OK]:%b       %d\n" "$GREEN" "$NC" "$TOTAL_OK"
  printf "  %bItens opcionais [AVISO]:%b    %d\n" "$YELLOW" "$NC" "$TOTAL_WARN"
  printf "  %bItens reprovados [FALHA]:%b   %d\n" "$RED" "$NC" "$TOTAL_FAIL"
  printf "%b===========================================================%b\n" "$BOLD" "$NC"

  if (( TOTAL_FAIL == 0 )); then
    printf "\n%b✔ Parabéns! Todos os componentes obrigatórios foram instalados com sucesso.%b\n\n" "$GREEN" "$NC"
  else
    printf "\n%b⚠ Atenção: Há componentes faltantes. Consulte o log em ~/kubuntu-postinstall-logs/ para investigar.%b\n\n" "$RED" "$NC"
  fi
}

main "$@"
