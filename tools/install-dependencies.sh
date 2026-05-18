#!/usr/bin/env bash
# IaC 작업에 필요한 CLI 도구를 한 번에 설치한다.
# 지원: Ubuntu / Debian (apt). macOS는 brew, Windows는 winget/WSL 권장 — README 참고.
#
# 설치 대상:
#   - AWS CLI v2  (공식 zip 인스톨러)
#   - Terraform   (HashiCorp apt repo)
#   - Ansible     (apt)
#   - community.general collection (Ansible)
#
# 이미 설치돼 있으면 그 단계는 건너뛴다.

set -euo pipefail

log() { printf "\n==> %s\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    cat >&2 <<'EOF'
이 스크립트는 Linux(Ubuntu/Debian)용입니다.
  - macOS  : brew install awscli ansible terraform
  - Windows: winget install Amazon.AWSCLI Hashicorp.Terraform
             (Ansible은 WSL에서 이 스크립트 실행 권장)
EOF
    exit 1
  fi
}

install_aws_cli() {
  if have aws; then
    log "AWS CLI 이미 설치됨: $(aws --version)"
    return
  fi
  log "AWS CLI v2 설치"
  local tmp; tmp=$(mktemp -d)
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp/aws.zip"
  unzip -q "$tmp/aws.zip" -d "$tmp"
  sudo "$tmp/aws/install"
  rm -rf "$tmp"
}

install_terraform() {
  if have terraform; then
    log "Terraform 이미 설치됨: $(terraform version | head -n1)"
    return
  fi
  log "Terraform 설치 (HashiCorp apt repo)"
  sudo apt-get update -y
  sudo apt-get install -y gnupg software-properties-common curl lsb-release
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y terraform
}

install_ansible() {
  if have ansible; then
    log "Ansible 이미 설치됨: $(ansible --version | head -n1)"
  else
    log "Ansible 설치 (apt)"
    sudo apt-get update -y
    sudo apt-get install -y ansible
  fi
  log "community.general collection 설치"
  ansible-galaxy collection install -U community.general
}

main() {
  require_linux
  install_aws_cli
  install_terraform
  install_ansible

  log "설치 완료. 버전 확인:"
  aws --version
  terraform version | head -n1
  ansible --version | head -n1
}

main "$@"
