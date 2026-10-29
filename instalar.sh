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
#  - O Odoo escuta só em 127.0.0.1; o instalador configura o Nginx para
#    publicá-lo em http://IP_DO_SERVIDOR (porta 80) e mostra o acesso no final.
#  - Variáveis opcionais:
#      PORTA_PUBLICA=8099  publica em outra porta (ex.: segunda instância)
#      PORTA_PUBLICA=0     não configura o Nginx (acesso só por túnel SSH)
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
PORTA_PUBLICA="${PORTA_PUBLICA:-80}"

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
if [ "$PORTA_PUBLICA" != "0" ]; then
  [[ "$PORTA_PUBLICA" =~ ^[0-9]+$ ]] || erro "PORTA_PUBLICA deve ser numérica."
  for p in "$PORTA" "$CHAT"; do [ "$PORTA_PUBLICA" != "$p" ] || erro "PORTA_PUBLICA deve ser diferente das portas internas."; done
  # Porta pública ocupada por outro programa (que não o Nginx)?
  if ss -ltnp 2>/dev/null | awk '{print $4, $6}' | grep -E "[:.]$PORTA_PUBLICA " | grep -vq nginx; then
    erro "a porta $PORTA_PUBLICA já está em uso por outro programa. Use PORTA_PUBLICA=<outra porta> ou PORTA_PUBLICA=0."
  fi
  # Porta pública já usada por outro site do Nginx (exceto a página padrão)?
  if [ -d /etc/nginx/sites-enabled ] && \
     grep -lsE "listen +(\[::\]:)?$PORTA_PUBLICA( |;)" /etc/nginx/sites-enabled/* | grep -v '/default$' | grep -q .; then
    erro "o Nginx já publica outro site na porta $PORTA_PUBLICA. Use PORTA_PUBLICA=<outra porta>, ex.: PORTA_PUBLICA=8099."
  fi
  command -v nginx >/dev/null || command -v apt-get >/dev/null || \
    erro "Nginx não encontrado e não há apt-get para instalá-lo. Instale o Nginx ou use PORTA_PUBLICA=0."
fi
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

URL="http://127.0.0.1:$PORTA"
if [ "$PORTA_PUBLICA" != "0" ]; then
  echo ">> Publicando pelo Nginx na porta $PORTA_PUBLICA"
  if ! command -v nginx >/dev/null; then
    { apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -y -q nginx; } </dev/null >/dev/null
  fi
  SITE="/etc/nginx/sites-available/odoo-$PROJETO"
  LISTEN6=""; [ -f /proc/net/if_inet6 ] && LISTEN6="listen [::]:$PORTA_PUBLICA;"
  cat > "$SITE" <<EOF
# Odoo 15 — instância $DESTINO (gerado pelo instalar.sh)
server {
  listen $PORTA_PUBLICA;
  $LISTEN6
  server_name _;
  client_max_body_size 200m;
  proxy_read_timeout 720s;
  proxy_connect_timeout 720s;
  proxy_send_timeout 720s;
  proxy_set_header Host \$http_host;
  proxy_set_header X-Forwarded-Host \$http_host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  location ~ ^/web/database/ { return 403; }
  location /longpolling { proxy_pass http://127.0.0.1:$CHAT; }
  location / { proxy_redirect off; proxy_pass http://127.0.0.1:$PORTA; }
}
EOF
  [ "$PORTA_PUBLICA" = "80" ] && rm -f /etc/nginx/sites-enabled/default
  ln -sf "$SITE" /etc/nginx/sites-enabled/
  nginx -t -q || erro "configuração do Nginx inválida ($SITE)."
  systemctl enable --now nginx >/dev/null 2>&1 || true
  systemctl reload nginx 2>/dev/null || nginx -s reload
  if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "$PORTA_PUBLICA/tcp" >/dev/null
  fi
  IP=$(curl -fsS --max-time 3 http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null \
       || hostname -I | awk '{print $1}')
  URL="http://$IP"; [ "$PORTA_PUBLICA" != "80" ] && URL="$URL:$PORTA_PUBLICA"
fi

echo ">> Aguardando o Odoo responder"
ok=0
for _ in $(seq 1 90); do
  if curl -fs -o /dev/null "http://127.0.0.1:$PORTA/web/login"; then ok=1; break; fi
  sleep 2
done

umask 077
cat > .credenciais <<EOF
Instância: $DESTINO   (gerado em $(date '+%F %T'))
Acesso: $URL
Base de dados: $BASE
Senha mestra (admin_passwd): $SENHA_MESTRA
EOF
if [ -n "$SENHA_ADMIN" ]; then
  printf 'Usuário: admin\nSenha do admin: %s\n' "$SENHA_ADMIN" >> .credenciais
fi
echo "Senha do PostgreSQL: arquivo secrets/db_password.txt" >> .credenciais
umask 022

echo
echo "=============================================================="
if [ "$ok" = "1" ]; then echo " Odoo 15 pronto"; else echo " Odoo 15 iniciado (ainda carregando; aguarde 1 minuto)"; fi
echo "   Acesse:  $URL"
if [ -n "$SENHA_ADMIN" ]; then
  echo "   Usuário: admin"
  echo "   Senha:   $SENHA_ADMIN"
fi
echo "   Senha mestra e demais dados: sudo cat $(pwd)/.credenciais"
echo "=============================================================="
if [ "$PORTA_PUBLICA" != "0" ]; then
  echo "Acesso por HTTP. Para HTTPS, aponte um domínio para este servidor e rode:"
  echo "   certbot --nginx -d SEU_DOMINIO --redirect"
  echo "Se o navegador não abrir, verifique o firewall de nuvem do provedor (porta $PORTA_PUBLICA)."
fi
