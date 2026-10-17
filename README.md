# 🚀 Kubuntu 26.04 LTS — Pós-Instalação Modular & Auditoria

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Kubuntu%20%7C%20Ubuntu-orange.svg)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contribuindo)

Scripts modulares e automatizados para configuração de ambiente pós-instalação no **Kubuntu 26.04.1 LTS (Noble Numbat / LTS)**, com script de auditoria e verificação de integridade.

---

## 📋 Conteúdo do Repositório

| Arquivo | Descrição |
|---|---|
| [`kubuntu-postinstall-26.04.sh`](kubuntu-postinstall-26.04.sh) | Script principal de pós-instalação modular. |
| [`verificar-pos-instalacao.sh`](verificar-pos-instalacao.sh) | Script de auditoria que valida a presença e versões de todas as ferramentas. |
| [`COMO_EXECUTAR.txt`](COMO_EXECUTAR.txt) | Guia rápido de execução em texto puro. |

---

## 🛠 O que é instalado e configurado?

### 1. Sistema e Ferramentas Base
- Ativação dos repositórios padrão: `main`, `universe`, `multiverse`, `restricted`.
- Atualização completa do sistema com `apt upgrade`.
- Ferramentas essenciais: `curl`, `wget`, `git`, `git-lfs`, `jq`, `unzip`, `zip`, `xz-utils`, `tar`, `rsync`.
- Compiladores e headers: `build-essential`, `dkms`, `linux-headers-$(uname -r)`.

### 2. Multimídia, Codecs e Documentos
- Metapacote `kubuntu-restricted-extras`.
- Codecs GStreamer completos (`base`, `good`, `bad`, `ugly`, `libav`).
- `ffmpeg`, `vlc` e leitor de documentos `okular`.
- Fontes essenciais (Noto Core/CJK/Emoji, Liberation, DejaVu, Microsoft Carlito/Caladea).

### 3. Flatpak e Integração com KDE Plasma
- Configuração do **Flathub** como repositório de usuário.
- Instalação do backend `plasma-discover-backend-flatpak` para integração nativa com o **KDE Discover**.
- Navegadores & Apps Flatpak:
  - **Chromium** (`org.chromium.Chromium`)
  - **LibreWolf** (`io.gitlab.librewolf-community`)
  - **DBeaver Community** (`io.dbeaver.DBeaverCommunity`)
  - **Podman Desktop** (`io.podman_desktop.PodmanDesktop`)
  - **RustDesk** (`com.rustdesk.RustDesk`)

### 4. Ambientes de Desenvolvimento
- **GitHub CLI (`gh`)**: via repositório oficial com chave segura em `/etc/apt/keyrings`.
- **Visual Studio Code (`code`)**: via repositório APT oficial da Microsoft.
- **Python**: `python3`, `pip`, `venv`, `pipx` e o gerenciador ultrarrápido **`uv`**.
- **Node.js**: gerenciador **NVM** configurando a versão LTS atual como padrão.
- **Java**: instalação de versões LTS disponíveis (`openjdk-25-jdk`, `openjdk-21-jdk`, `openjdk-17-jdk` ou `default-jdk`).
- **Contêineres Rootless**: `podman`, `podman-compose`, `buildah`, `skopeo`.

### 5. Diagnóstico de Rede & Hardware
- `openssh-client`, `dnsutils`, `mtr-tiny`, `traceroute`, `nmap`, `btop`, `smartmontools`, `lm-sensors`.
- Detecção automática de VM: instala **VirtualBox Guest Additions** apenas se estiver rodando em uma máquina virtual VirtualBox.

---

## 🚀 Como Executar

### Pré-requisitos
- Kubuntu ou Ubuntu 26.04 LTS instalado.
- Conexão com a internet ativa.
- Executar como **utilizador comum** (o script solicitará `sudo` quando necessário e manterá o token ativo em segundo plano).

### Passo a Passo

```bash
# 1. Clone o repositório
git clone https://github.com/Edk1990/kubuntu-postinstall.git
cd kubuntu-postinstall

# 2. Conceda permissão de execução
chmod +x kubuntu-postinstall-26.04.sh verificar-pos-instalacao.sh

# 3. Execute o script principal (SEM sudo!)
./kubuntu-postinstall-26.04.sh

# 4. Reinicie o sistema após o término
sudo reboot
```

> [!TIP]
> Caso tenha feito download manual ou editado no Windows, converta as quebras de linha com:
> `sed -i 's/\r$//' kubuntu-postinstall-26.04.sh`

---

## 🔍 Como Auditar a Instalação

Após a instalação e reinicialização, execute o script de verificação:

```bash
./verificar-pos-instalacao.sh
```

O script realizará uma checagem completa de integridade sem alterar nada no sistema, exibindo um relatório com versões e status `[OK]`, `[OPCIONAL]` ou `[FALHA]`.

---

## 🤝 Contribuindo

Contribuições, correções de bugs, sugestões e forks são muito bem-vindos!

1. Faça um **Fork** do projeto.
2. Crie uma branch para a sua feature (`git checkout -b feature/minha-melhoria`).
3. Commit suas alterações (`git commit -m 'feat: adiciona módulo X'`).
4. Envie para o branch (`git push origin feature/minha-melhoria`).
5. Abra um **Pull Request**.

---

## 📄 Licença

Distribuído sob a licença **MIT**. Consulte o arquivo [`LICENSE`](LICENSE) para mais detalhes.
