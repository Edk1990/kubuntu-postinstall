#!/usr/bin/env bash
# Kubuntu 26.04.1 LTS — pós-instalação modular
# Execute como utilizador normal, sem sudo. O script pedirá sudo quando necessário.
# Não configura credenciais, acesso remoto não assistido, firewall nem backups agendados.
set -Eeuo pipefail
IFS=$'\n\t'
umask 022

LOG_DIR="${HOME}/kubuntu-postinstall-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/postinstall-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
declare -a OK=() WARNINGS=() FAILURES=()
APT_UPDATED=0

info() { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b[AVISO]%b %s\n' "$YELLOW" "$NC" "$*"; WARNINGS+=("$*"); }
error() { printf '%b[ERRO]%b %s\n' "$RED" "$NC" "$*"; FAILURES+=("$*"); }
mark_ok() { OK+=("$*"); info "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }

ask_yes_no() {
  local prompt="$1" default="${2:-N}" answer
  while true; do
    if [[ "$default" == "S" ]]; then
      read -r -p "$prompt [S/n] " answer || answer=""
      answer="${answer:-S}"
    else
      read -r -p "$prompt [s/N] " answer || answer=""
      answer="${answer:-N}"
    fi
    case "$answer" in
      [sS]|[sS][iI][mM]) return 0 ;;
      [nN]|[nN][ãÃaA][oO]) return 1 ;;
      *) echo "Responda S ou N." ;;
    esac
  done
}

apt_update_once() {
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    sudo apt-get update
    APT_UPDATED=1
  fi
}

pkg_available() { apt-cache show "$1" >/dev/null 2>&1; }

apt_install_available() {
  local packages=() package
  for package in "$@"; do
    if pkg_available "$package"; then
      packages+=("$package")
    else
      warn "Pacote não encontrado nos repositórios atualmente configurados: $package"
    fi
  done
  ((${#packages[@]})) || return 0
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

run_module() {
  local label="$1" function_name="$2"
  info "Início: $label"
  if "$function_name"; then
    mark_ok "$label"
  else
    error "$label (consulte o log para detalhes)"
  fi
}

check_os() {
  [[ -r /etc/os-release ]] || { error "Não foi possível identificar o sistema operacional."; return 1; }
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *ubuntu* ]]; then
    warn "Distribuição detectada: ${PRETTY_NAME:-desconhecida}; o script foi preparado para Kubuntu/Ubuntu."
    ask_yes_no "Continuar mesmo assim?" N || return 1
  fi
  if [[ "${VERSION_ID:-}" != "26.04" ]]; then
    warn "Versão detectada: ${PRETTY_NAME:-desconhecida}; o plano foi preparado para Kubuntu 26.04.x."
    ask_yes_no "Continuar mesmo assim?" N || return 1
  fi
  local arch
  arch="$(dpkg --print-architecture)"
  if [[ "$arch" != "amd64" && "$arch" != "arm64" ]]; then
    warn "Arquitetura $arch pode não ser suportada por todos os programas externos."
  fi
}

install_base() {
  info "Garantindo repositórios padrão (main, universe, multiverse, restricted)..."
  sudo add-apt-repository -y universe multiverse restricted >/dev/null 2>&1 || true
  apt_update_once
  sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  apt_install_available ca-certificates curl wget gnupg gpg apt-transport-https software-properties-common \
    build-essential dkms "linux-headers-$(uname -r)" lsb-release git git-lfs jq unzip zip xz-utils tar rsync
  sudo apt-get autoremove -y
}

install_codecs_fonts_archives() {
  apt_update_once
  apt_install_available kubuntu-restricted-extras ffmpeg vlc \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji fonts-liberation \
    fonts-dejavu-core fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea \
    zip unzip 7zip p7zip-full unrar-free unrar
  warn "A disponibilidade de codecs e fontes depende dos repositórios habilitados; reveja os avisos do APT."
}

setup_flatpak() {
  apt_update_once
  apt_install_available flatpak plasma-discover-backend-flatpak
  has flatpak || { warn "Flatpak não ficou disponível após a instalação."; return 1; }
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

flatpak_install() {
  local app_id="$1"
  has flatpak || { warn "Flatpak ausente; não foi possível instalar $app_id."; return 1; }
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --user --assumeyes flathub "$app_id"
}

install_flatpak_apps() {
  setup_flatpak
  flatpak_install org.chromium.Chromium
  flatpak_install io.gitlab.librewolf-community
  flatpak_install io.dbeaver.DBeaverCommunity
  flatpak_install io.podman_desktop.PodmanDesktop
}

install_pdf() {
  apt_update_once
  apt_install_available okular
}

add_apt_repo_key() {
  local url="$1" destination="$2" temp
  temp="$(mktemp)"
  if ! curl -fsSL "$url" -o "$temp"; then
    rm -f "$temp"
    return 1
  fi
  sudo install -d -m 0755 "$(dirname "$destination")"
  if grep -q -- '-----BEGIN PGP' "$temp"; then
    sudo gpg --dearmor --yes -o "$destination" "$temp"
  else
    sudo cp "$temp" "$destination"
  fi
  sudo chmod 0644 "$destination"
  rm -f "$temp"
}

install_remote_clients() {
  flatpak_install com.rustdesk.RustDesk
  # Usa o repositório APT oficial do AnyDesk e a chave dedicada.
  if add_apt_repo_key https://keys.anydesk.com/repos/DEB-GPG-KEY /etc/apt/keyrings/keys.anydesk.com.gpg; then
    printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.gpg] https://deb.anydesk.com/ all main' | \
      sudo tee /etc/apt/sources.list.d/anydesk.list >/dev/null
    APT_UPDATED=0
    apt_update_once
    apt_install_available anydesk
  else
    warn "Não foi possível obter a chave oficial do AnyDesk; o módulo foi parcialmente ignorado."
  fi
  warn "RustDesk/AnyDesk serão instalados sem configurar acesso não assistido, senhas ou regras de firewall."
}

install_github_cli() {
  has gh && return 0
  sudo install -d -m 0755 /etc/apt/keyrings
  add_apt_repo_key https://cli.github.com/packages/githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg
  local arch
  arch="$(dpkg --print-architecture)"
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$arch" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  APT_UPDATED=0
  apt_update_once
  apt_install_available gh
}

install_vscode() {
  has code && return 0
  sudo install -d -m 0755 /etc/apt/keyrings
  add_apt_repo_key https://packages.microsoft.com/keys/microsoft.asc /etc/apt/keyrings/microsoft.gpg
  local arch
  arch="$(dpkg --print-architecture)"
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' "$arch" | \
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  APT_UPDATED=0
  apt_update_once
  apt_install_available code
}

install_python() {
  apt_update_once
  apt_install_available python3 python3-pip python3-venv python3-dev pipx
  export PATH="$HOME/.local/bin:$PATH"
  if has pipx; then
    pipx ensurepath >/dev/null 2>&1 || true
  fi
  if ! has uv; then
    if has pipx; then
      pipx install uv || pipx upgrade uv
    else
      warn "pipx não está disponível; uv não foi instalado automaticamente."
    fi
  fi
  warn "Utilize ambientes virtuais para dependências Python; o script não executa pip como root."
}

install_nvm_node() {
  apt_update_once
  apt_install_available git curl ca-certificates
  local nvm_dir="$HOME/.nvm" rc
  if [[ ! -d "$nvm_dir/.git" ]]; then
    git clone --depth 1 https://github.com/nvm-sh/nvm.git "$nvm_dir"
  else
    git -C "$nvm_dir" fetch --depth 1 origin
    git -C "$nvm_dir" reset --hard FETCH_HEAD
  fi
  local rc_targets=("$HOME/.bashrc")
  if [[ -f "$HOME/.zshrc" ]] || has zsh; then
    rc_targets+=("$HOME/.zshrc")
  fi
  for rc in "${rc_targets[@]}"; do
    touch "$rc"
    if ! grep -Fq 'NVM_DIR="$HOME/.nvm"' "$rc"; then
      cat >> "$rc" <<'NVMRC'

# NVM — adicionado pelo script de pós-instalação do Kubuntu
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
NVMRC
    fi
  done
  export NVM_DIR="$nvm_dir"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
}

install_java() {
  apt_update_once
  local candidates=() package
  # Instala versões LTS disponíveis nos repositórios; não presume que todas existam.
  for package in openjdk-25-jdk openjdk-21-jdk openjdk-17-jdk; do
    pkg_available "$package" && candidates+=("$package")
  done
  if ((${#candidates[@]})); then
    apt_install_available "${candidates[@]}"
  else
    apt_install_available default-jdk
  fi
  warn "Confira as versões com 'update-java-alternatives --list' e altere as alternativas conforme necessário."
}

install_podman() {
  apt_update_once
  apt_install_available podman podman-compose buildah skopeo uidmap slirp4netns fuse-overlayfs
  if has podman; then
    podman info >/dev/null 2>&1 || warn "Podman instalado, mas 'podman info' requer verificação de configuração."
  fi
}

install_network() {
  apt_update_once
  apt_install_available openssh-client openssh-server dnsutils mtr-tiny traceroute nmap netcat-openbsd iproute2 iputils-ping whois
  warn "O servidor SSH não será ativado nem exposto automaticamente; configure-o apenas se precisar receber ligações."
}

install_hardware() {
  apt_update_once
  apt_install_available linux-firmware ubuntu-drivers-common btop lm-sensors smartmontools
  if has ubuntu-drivers; then
    warn "Lista de drivers recomendados (não serão instalados automaticamente):"
    ubuntu-drivers devices || true
  fi
  warn "A deteção de sensores pode exigir 'sudo sensors-detect'; execute-o interativamente e reveja cada pergunta."
}

install_virtualbox_guest() {
  local virt
  virt="$(systemd-detect-virt 2>/dev/null || true)"
  if [[ "$virt" != "oracle" ]]; then
    info "Sistema não está em execução no VirtualBox (detectado: ${virt:-máquina física/outro}). Módulo ignorado."
    return 0
  fi
  apt_update_once
  apt_install_available virtualbox-guest-utils virtualbox-guest-x11 virtualbox-guest-dkms
  warn "Se as Guest Additions não funcionarem, use Dispositivos > Inserir imagem de CD das Guest Additions no VirtualBox e consulte a documentação do anfitrião."
}

install_backup_basics() {
  apt_update_once
  apt_install_available rsync deja-dup
  warn "Não será configurado nenhum destino, agendamento ou política automática de backup."
}

install_antigravity_cli() {
  if has agy || [[ -x "$HOME/.local/bin/agy" ]]; then return 0; fi
  warn "O instalador da CLI Antigravity é remoto; o script descarrega-o e pede autorização antes de o executar."
  local installer
  installer="$(mktemp)"
  curl -fsSL https://antigravity.google/cli/install.sh -o "$installer"
  if ask_yes_no "Executar o instalador oficial descarregado da CLI Antigravity?" N; then
    bash "$installer"
  else
    warn "Instalação da CLI Antigravity adiada."
  fi
  rm -f "$installer"
  has agy || [[ -x "$HOME/.local/bin/agy" ]] || warn "Confirme manualmente se a CLI Antigravity foi instalada."
}

antigravity_manual() {
  warn "Antigravity Desktop/IDE não foi instalado automaticamente: os artefactos e instruções oficiais podem mudar."
  printf 'Página oficial: https://antigravity.google/download\n'
  printf 'Descarregue o pacote compatível com a arquitetura e siga as instruções atuais do projeto.\n'
}

install_scion_harness() {
  if ! has scion; then
    warn "Harness Scion pendente: o comando 'scion' não está instalado. Não foi presumida uma origem para instalar o executável."
    printf 'Consulte a documentação oficial do Scion antes de instalar: https://googlecloudplatform.github.io/scion/\n'
    printf 'Depois de validar a instalação, consulte a documentação do bundle Antigravity Harness e execute o comando oficial indicado.\n'
    return 0
  fi
  warn "Scion já está instalado. Por segurança, confirme na documentação atual o identificador exato do bundle Antigravity antes de executar a instalação."
}

summary() {
  printf '\n========== RESUMO ==========\nLog: %s\n' "$LOG_FILE"
  printf '\nConcluídos (%d):\n' "${#OK[@]}"
  ((${#OK[@]})) && printf '  - %s\n' "${OK[@]}" || true
  printf '\nAvisos/pendências (%d):\n' "${#WARNINGS[@]}"
  ((${#WARNINGS[@]})) && printf '  - %s\n' "${WARNINGS[@]}" || true
  printf '\nFalhas (%d):\n' "${#FAILURES[@]}"
  ((${#FAILURES[@]})) && printf '  - %s\n' "${FAILURES[@]}" || true
  printf '\nReinicie a sessão ou o sistema se forem instalados novos Flatpaks, kernel ou firmware.\n'
}

main() {
  printf 'Pós-instalação Kubuntu 26.04.1 LTS\nLog: %s\n' "$LOG_FILE"
  if [[ $EUID -eq 0 ]]; then
    echo "Não execute como root nem com sudo; execute como o seu utilizador normal."
    exit 1
  fi
  has sudo || { echo "O comando sudo não está disponível."; exit 1; }
  check_os || { error "Verificação inicial cancelada ou falhou."; summary; exit 1; }
  sudo -v
  # Mantém o sudo ativo em segundo plano durante a execução
  local sudo_keepalive_pid
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  sudo_keepalive_pid=$!
  trap 'kill "$sudo_keepalive_pid" 2>/dev/null || true' EXIT

  echo
  echo "O script instalará software e atualizará o sistema. Repositórios externos serão limitados aos fornecedores identificados no script."
  ask_yes_no "Prosseguir com a instalação dos módulos planeados?" N || { echo "Cancelado sem alterações."; exit 0; }

  run_module "Atualizações e ferramentas essenciais" install_base
  run_module "Codecs, fontes e compactadores" install_codecs_fonts_archives
  run_module "Flatpak, Flathub, Chromium, LibreWolf, DBeaver e Podman Desktop" install_flatpak_apps
  run_module "Okular e ferramentas PDF" install_pdf
  run_module "RustDesk e AnyDesk" install_remote_clients
  run_module "GitHub CLI" install_github_cli
  run_module "Visual Studio Code" install_vscode
  run_module "Python, pip, venv e uv" install_python
  run_module "Node.js via NVM" install_nvm_node
  run_module "OpenJDK LTS e alternativas" install_java
  run_module "Podman, podman-compose, Buildah e Skopeo" install_podman
  run_module "OpenSSH e ferramentas de diagnóstico de rede" install_network
  run_module "Firmware, drivers e monitorização" install_hardware
  run_module "VirtualBox Guest Additions" install_virtualbox_guest
  run_module "Ferramentas básicas de backup" install_backup_basics
  run_module "Antigravity CLI (agy)" install_antigravity_cli
  run_module "Antigravity Desktop/IDE (instruções oficiais)" antigravity_manual
  run_module "Google Antigravity Harness / Scion (validação manual)" install_scion_harness
  summary
}

main "$@"
