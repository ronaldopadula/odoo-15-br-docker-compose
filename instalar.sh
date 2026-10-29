#!/usr/bin/env bash
# =============================================================================
#  Instala uma instância do Odoo 15 com Docker Compose.
#
#  Uso:
#    sudo ./instalar.sh <pasta> <porta> <porta_chat> [nome_da_base]
#
#  Exemplo:
#    sudo ./instalar.sh odoo15-one 10015 20015 empresa
#
#  - Gera senhas aleatórias (banco, senha mestra, usuário admin) e as guarda
#    em <pasta>/.credenciais, legível só pelo root.
#  - Publica o Odoo apenas em 127.0.0.1; o acesso externo é pelo Nginx (veja
#    nginx/odoo.conf.example e o README).
#  - Variáveis opcionais:
#      CRIAR_BASE=0        não cria base nova (ex.: para restaurar um dump)
#      REF=<branch|tag>    versão deste repositório a usar (padrão: master)
#      ODOO_IMAGE / POSTGRES_IMAGE   imagens (padrão: odoo:15.0 / postgres:16)
# =============================================================================
set -euo pipefail

DESTINO="${1:-}"; PORTA="${2:-}"; CHAT="${3:-}"; BASE="${4:-odoo}"
REPO="${REPO:-https://github.com/ronaldopadula/odoo-15-br-docker-compose}"
REF="${REF:-master}"
CRIAR_BASE="${CRIAR_BASE:-1}"
ODOO_IMAGE="${ODOO_IMAGE:-odoo:15.0}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16}"

uso() { sed -n '2,20p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 1; }
erro() { echo "ERRO: $*" >&2; exit 1; }

[ -n "$DESTINO" ] && [ -n "$PORTA" ] && [ -n "$CHAT" ] || uso
[ "$(id -u)" -eq 0 ] || erro "rode com sudo."
[[ "$PORTA" =~ ^[0-9]+$ && "$CHAT" =~ ^[0-9]+$ ]] || erro "portas devem ser numéricas."
[ "$PORTA" -ge 1024 ] && [ "$PORTA" -le 65535 ] && [ "$CHAT" -ge 1024 ] && [ "$CHAT" -le 65535 ] || erro "use portas entre 1024 e 65535."
[ "$PORTA" != "$CHAT" ] || erro "as duas portas devem ser diferentes."
[[ "$BASE" =~ ^[a-zA-Z0-9_]+$ ]] || erro "nome da base: use só letras, números e _."
[ ! -e "$DESTINO" ] || erro "a pasta $DESTINO já existe."
for p in "$PORTA" "$CHAT"; do
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$p\$"; then erro "a porta $p já está em uso."; fi
done

command -v docker >/dev/null || erro "Docker não encontrado: https://docs.docker.com/engine/install/"
if docker compose version >/dev/null 2>&1; then DC=(docker compose)
elif command -v docker-compose >/dev/null; then DC=(docker-compose)
else erro "Docker Compose não encontrado."; fi
command -v openssl >/dev/null || erro "openssl não encontrado."
command -v git >/dev/null || erro "git não encontrado."

gerar() { openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-"$1"; }

echo ">> Baixando o projeto ($REF) em $DESTINO"
git clone -q --depth=1 -b "$REF" "$REPO" "$DESTINO"
rm -rf "$DESTINO/.git"
cd "$DESTINO"

echo ">> Gerando senhas e configuração"
umask 077
mkdir -p postgresql secrets addons
gerar 32 > secrets/db_password.txt
SENHA_MESTRA=$(gerar 24)
sed -e "s|__ADMIN_PASSWD__|$SENHA_MESTRA|" -e "s|__DBFILTER__|^${BASE}\$|" \
    etc/odoo.conf.example > etc/odoo.conf
PROJETO=$(basename "$DESTINO" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n_-' '_')
cat > .env <<EOF
COMPOSE_PROJECT_NAME=$PROJETO
ODOO_PORT=$PORTA
CHAT_PORT=$CHAT
ODOO_IMAGE=$ODOO_IMAGE
POSTGRES_IMAGE=$POSTGRES_IMAGE
EOF
umask 022

echo ">> Ajuste do sistema (inotify, para várias instâncias)"
echo "fs.inotify.max_user_watches = 524288" > /etc/sysctl.d/90-odoo-inotify.conf
sysctl -q -p /etc/sysctl.d/90-odoo-inotify.conf || true

echo ">> Baixando as imagens e fixando as versões (digest)"
"${DC[@]}" pull -q </dev/null
for var in ODOO_IMAGE POSTGRES_IMAGE; do
  img=$(grep "^$var=" .env | cut -d= -f2-)
  dig=$(docker image inspect --format '{{index .RepoDigests 0}}' "$img" 2>/dev/null || true)
  [ -n "$dig" ] && sed -i "s|^$var=.*|$var=$dig|" .env
done

echo ">> Permissões (sem 777; o Odoo roda sem root)"
OUID=$(docker run --rm --entrypoint id "$(grep '^ODOO_IMAGE=' .env | cut -d= -f2-)" -u)
OGID=$(docker run --rm --entrypoint id "$(grep '^ODOO_IMAGE=' .env | cut -d= -f2-)" -g)
chown -R "$OUID:$OGID" etc addons secrets/db_password.txt
chmod 750 etc addons
chmod 640 etc/odoo.conf
chmod 400 secrets/db_password.txt
chmod 700 secrets
chmod 600 .env

echo ">> Iniciando o PostgreSQL"
"${DC[@]}" up -d db </dev/null
for _ in $(seq 1 60); do
  "${DC[@]}" exec -T db pg_isready -U odoo -q </dev/null 2>/dev/null && break
  sleep 1
done
"${DC[@]}" exec -T db pg_isready -U odoo -q </dev/null || erro "o PostgreSQL não respondeu."

SENHA_ADMIN=""
if [ "$CRIAR_BASE" = "1" ]; then
  echo ">> Criando a base '$BASE' (sem dados de demonstração, em português)"
  "${DC[@]}" run --rm -T odoo15 odoo -d "$BASE" -i base --without-demo=all \
      --load-language=pt_BR --stop-after-init --no-http </dev/null
  SENHA_ADMIN=$(gerar 16)
  printf "u = env.ref('base.user_admin')\nu.password = '%s'\nu.lang = 'pt_BR'\nenv.cr.commit()\n" "$SENHA_ADMIN" \
    | "${DC[@]}" run --rm -T odoo15 odoo shell -d "$BASE" --no-http >/dev/null
fi

echo ">> Iniciando o Odoo"
"${DC[@]}" up -d </dev/null

umask 077
cat > .credenciais <<EOF
Instância: $DESTINO   (gerado em $(date '+%F %T'))
Endereço local: http://127.0.0.1:$PORTA   (externo: via Nginx, ver README)
Base de dados: $BASE
Senha mestra (admin_passwd): $SENHA_MESTRA
EOF
if [ -n "$SENHA_ADMIN" ]; then
  printf 'Usuário: admin\nSenha do admin: %s\n' "$SENHA_ADMIN" >> .credenciais
fi
echo "Senha do PostgreSQL: arquivo secrets/db_password.txt" >> .credenciais
umask 022

echo
echo "Odoo 15 iniciado em 127.0.0.1:$PORTA (live chat em 127.0.0.1:$CHAT)."
echo "Senhas geradas: $(pwd)/.credenciais   (leia com: sudo cat $(pwd)/.credenciais)"
echo "Para publicar com HTTPS, configure o Nginx conforme nginx/odoo.conf.example."
