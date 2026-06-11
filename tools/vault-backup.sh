#!/usr/bin/env bash
#
# MOA 인프라 시크릿을 개인 Vaultwarden(vault.yeoun.org)에 백업한다.
# 배경/항목 목록은 docs/secrets-and-vault-backup.md 참고.
#
# 특징:
#   - 비밀값은 이 스크립트에 없다. 실행 시점에 terraform state(S3)에서 직접 읽어 bw로 넣는다.
#   - API 키(client_id/secret)도 없다. 이미 apikey 로그인된 bw 상태를 재사용한다.
#   - 마스터 비밀번호는 bw unlock 프롬프트에서 직접 입력한다(디스크/로그에 안 남음).
#   - 멱등: 같은 이름 항목이 있으면 갱신(update), 없으면 생성. 여러 번 돌려도 중복 안 생김.
#
# 사전조건:
#   - AWS 자격증명(state 읽기 권한)  : aws sts get-caller-identity 통과
#   - bw가 apikey로 로그인돼 있어야 함 :
#       export BITWARDENCLI_APPDATA_DIR="$HOME/.config/Bitwarden CLI"
#       bw config server https://vault.yeoun.org
#       BW_CLIENTID='user.…' BW_CLIENTSECRET='…' bw login --apikey
#
# 실행: bash tools/vault-backup.sh
#
set -euo pipefail

export BITWARDENCLI_APPDATA_DIR="$HOME/.config/Bitwarden CLI"

TF_BUCKET="sw-hub-dev-tfstate-850919911012"
TF_KEY="dev/terraform.tfstate"
FOLDER_NAME="MOA Infra"

# --- 0. 의존성 확인 ---
for c in bw jq aws; do
  command -v "$c" >/dev/null || { echo "ERROR: '$c' 없음"; exit 1; }
done

# --- 1. bw 로그인/서버 상태 확인 ---
# bw는 '로그인된' 프로필의 server 변경을 거부한다("Logout required before server config update").
# 그래서 서버가 아직 vault.yeoun.org가 아닐 때(=로그아웃 상태)만 설정한다.
CUR_SRV="$(bw status | jq -r '.serverUrl // empty')"
if [ "$CUR_SRV" != "https://vault.yeoun.org" ]; then
  bw config server https://vault.yeoun.org >/dev/null
fi
ST="$(bw status | jq -r '.status')"
if [ "$ST" = "unauthenticated" ]; then
  echo "ERROR: 이 appdata 프로필($BITWARDENCLI_APPDATA_DIR)에 로그인 안 됨. 먼저:"
  echo "  BITWARDENCLI_APPDATA_DIR='$BITWARDENCLI_APPDATA_DIR' BW_CLIENTID='user.…' BW_CLIENTSECRET='…' bw login --apikey"
  exit 1
fi

# --- 2. AWS 자격증명 확인 ---
aws sts get-caller-identity >/dev/null 2>&1 || { echo "ERROR: AWS 자격증명 없음/만료. 로그인 후 재실행."; exit 1; }

# --- 3. 마스터 비밀번호로 unlock (여기서 직접 입력) ---
echo ">> Vaultwarden unlock — 마스터 비밀번호를 입력하세요:"
BW_SESSION="$(bw unlock --raw)"
export BW_SESSION
bw sync >/dev/null
echo "   unlocked."

# --- 4. terraform state 가져오기 (임시, 600) ---
umask 077
TF_STATE="$(mktemp -t moa-state.XXXXXX)"
cleanup() { rm -f "$TF_STATE"; bw lock >/dev/null 2>&1 || true; }
trap cleanup EXIT
aws s3 cp "s3://${TF_BUCKET}/${TF_KEY}" "$TF_STATE" --quiet
echo "   state pulled."

# --- 5. 값 추출 (로컬 셸 변수, 출력 안 함) ---
RDS_EP="$(jq -r '.outputs.rds_endpoint.value' "$TF_STATE")"
RDS_PW="$(jq -r '.outputs.rds_password.value' "$TF_STATE")"
PROD_KEY="$(jq -r '.resources[]|select(.module=="module.ec2_prod" and .type=="tls_private_key")|.instances[0].attributes.private_key_openssh' "$TF_STATE")"
DEV_KEY="$(jq -r '.resources[]|select(.module=="module.ec2_dev" and .type=="tls_private_key")|.instances[0].attributes.private_key_openssh' "$TF_STATE")"
PROD_TOK="$(jq -r '.outputs.cloudflare_tunnel_tokens.value.prod' "$TF_STATE")"
DEV_TOK="$(jq -r '.outputs.cloudflare_tunnel_tokens.value.dev' "$TF_STATE")"

for v in RDS_EP RDS_PW PROD_KEY DEV_KEY PROD_TOK DEV_TOK; do
  [ -n "${!v}" ] && [ "${!v}" != "null" ] || { echo "ERROR: $v 비어있음(state 확인)"; exit 1; }
done

# --- 6. 폴더 get/create ---
FOLDER_ID="$(bw list folders --search "$FOLDER_NAME" | jq -r --arg n "$FOLDER_NAME" 'map(select(.name==$n))[0].id // empty')"
if [ -z "$FOLDER_ID" ]; then
  FOLDER_ID="$(jq -nc --arg n "$FOLDER_NAME" '{name:$n}' | bw encode | bw create folder | jq -r '.id')"
  echo "   folder created: $FOLDER_NAME"
else
  echo "   folder exists:  $FOLDER_NAME"
fi

# --- 7. 멱등 upsert ---
upsert() {
  local name="$1" json="$2" id
  id="$(bw list items --search "$name" | jq -r --arg n "$name" 'map(select(.name==$n))[0].id // empty')"
  if [ -n "$id" ]; then
    printf '%s' "$json" | bw encode | bw edit item "$id" >/dev/null
    echo "   updated: $name"
  else
    printf '%s' "$json" | bw encode | bw create item >/dev/null
    echo "   created: $name"
  fi
}

# 7a. RDS (login)
RDS_NOTES="host: ${RDS_EP}
databases: moa_prod (prod) / moa_dev (dev)
engine: postgres + pgvector · 공유 인스턴스 1대 (moa-prod-db)
master user: moa_admin"
upsert "MOA · RDS (moa-db, shared)" "$(jq -nc \
  --arg name "MOA · RDS (moa-db, shared)" --arg fid "$FOLDER_ID" \
  --arg user "moa_admin" --arg pass "$RDS_PW" --arg notes "$RDS_NOTES" \
  '{type:1,name:$name,folderId:$fid,notes:$notes,favorite:false,reprompt:0,fields:[],
    login:{uris:[],username:$user,password:$pass,totp:null},secureNote:null}')"

# 7b. moa-prod SSH (secure note, key in notes)
upsert "MOA · EC2 moa-prod SSH" "$(jq -nc \
  --arg name "MOA · EC2 moa-prod SSH" --arg fid "$FOLDER_ID" --arg key "$PROD_KEY" \
  '{type:2,name:$name,folderId:$fid,notes:$key,favorite:false,reprompt:0,
    secureNote:{type:0},
    fields:[{name:"host",value:"3.39.252.60",type:0,linkedId:null},
            {name:"user",value:"ubuntu",type:0,linkedId:null},
            {name:"instance",value:"moa-prod",type:0,linkedId:null}]}')"

# 7c. moa-dev SSH
upsert "MOA · EC2 moa-dev SSH" "$(jq -nc \
  --arg name "MOA · EC2 moa-dev SSH" --arg fid "$FOLDER_ID" --arg key "$DEV_KEY" \
  '{type:2,name:$name,folderId:$fid,notes:$key,favorite:false,reprompt:0,
    secureNote:{type:0},
    fields:[{name:"host",value:"43.203.227.207",type:0,linkedId:null},
            {name:"user",value:"ubuntu",type:0,linkedId:null},
            {name:"instance",value:"moa-dev",type:0,linkedId:null}]}')"

# 7d. Cloudflare tunnel token — prod (token in hidden field)
upsert "MOA · CF tunnel token (prod)" "$(jq -nc \
  --arg name "MOA · CF tunnel token (prod)" --arg fid "$FOLDER_ID" --arg tok "$PROD_TOK" \
  '{type:2,name:$name,folderId:$fid,
    notes:"hostname: moa.yeoun.org\ntunnel: moa-prod\n사용: cloudflared tunnel run --token <token>",
    favorite:false,reprompt:0,secureNote:{type:0},
    fields:[{name:"token",value:$tok,type:1,linkedId:null}]}')"

# 7e. Cloudflare tunnel token — dev
upsert "MOA · CF tunnel token (dev)" "$(jq -nc \
  --arg name "MOA · CF tunnel token (dev)" --arg fid "$FOLDER_ID" --arg tok "$DEV_TOK" \
  '{type:2,name:$name,folderId:$fid,
    notes:"hostname: dev-moa.yeoun.org\ntunnel: moa-dev\n사용: cloudflared tunnel run --token <token>",
    favorite:false,reprompt:0,secureNote:{type:0},
    fields:[{name:"token",value:$tok,type:1,linkedId:null}]}')"

echo ""
echo "완료. '$FOLDER_NAME' 폴더에 5개 항목 저장됨. (state 임시파일 삭제·vault lock 처리)"
echo "권장: 노출된 적 있는 Vaultwarden API 키는 회전."
