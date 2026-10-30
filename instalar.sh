#!/usr/bin/env bash
# =============================================================================
#  Instala uma instância do Odoo (versão 14, 15, 16 ou 18) com Docker Compose.
#
#  Uso:
#    sudo [VERSAO=14|15|16|18] bash instalar.sh <pasta> <porta> [base_inicial]
#
#  Exemplos:
#    sudo bash instalar.sh odoo15-one 10015                 # Odoo 15 em http://IP:10015
#    sudo VERSAO=18 bash instalar.sh odoo18 10018           # Odoo 18 em http://IP:10018
#    sudo VERSAO=16 bash instalar.sh odoo16 10016           # Odoo 16 em http://IP:10016
#    sudo VERSAO=14 bash instalar.sh odoo14 10014 empresa   # Odoo 14, já cria a base "empresa"
#    sudo DOMINIO=erp.exemplo.com.br bash instalar.sh odoo15-prod 10015
#                                                           # acesso: https://erp.exemplo.com.br
#
#  - Se faltarem, instala sozinho o Docker e o git (Ubuntu/Debian).
#  - Cada instância tem uma porta própria e atende várias bases (seleção no login).
#  - Gerenciador de Bancos disponível pelo navegador, protegido por usuário e
#    senha do proxy e pela senha mestra do Odoo (ambas geradas na instalação).
#  - O Odoo e o PostgreSQL não ficam expostos; só o proxy (Caddy) recebe conexões.
#  - Com DOMINIO=..., o Caddy emite e renova o certificado HTTPS sozinho
#    (o domínio deve apontar para o servidor e as portas 80/443 devem estar livres).
#  - Variáveis opcionais:
#      VERSAO=14|15|16|18  versão do Odoo (padrão: 15)
#      DOMINIO=<domínio>   publica com HTTPS automático (uso em produção)
#      EMAIL=<e-mail>      contato para o Let's Encrypt (opcional, com DOMINIO)
#      REF=<branch|tag>    versão deste repositório (padrão: master)
#      ODOO_IMAGE / POSTGRES_IMAGE / CADDY_IMAGE   imagens (padrão: odoo:<VERSAO>.0 /
#                          PostgreSQL compatível com a imagem do Odoo, até o 16 / caddy:2)
# =============================================================================
set -euo pipefail

DESTINO="${1:-}"; PORTA="${2:-}"; BASE="${3:-}"
# Compatibilidade com a forma antiga: <pasta> <porta> <porta_chat> [base]
if [[ "$BASE" =~ ^[0-9]+$ ]]; then
  echo "Aviso: a porta de chat ($BASE) não é mais necessária e foi ignorada."
  BASE="${4:-}"
fi
VERSAO="${VERSAO:-15}"
DOMINIO="${DOMINIO:-}"
EMAIL="${EMAIL:-}"
REPO="${REPO:-https://github.com/ronaldopadula/odoo-15-br-docker-compose}"
REF="${REF:-master}"
ODOO_IMAGE="${ODOO_IMAGE:-odoo:$VERSAO.0}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-}"   # vazio: escolhido conforme a imagem do Odoo
CADDY_IMAGE="${CADDY_IMAGE:-caddy:2}"

uso() { sed -n '2,30p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 1; }
erro() { echo "ERRO: $*" >&2; exit 1; }
porta_ocupada() { ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$1\$"; }

[ -n "$DESTINO" ] && [ -n "$PORTA" ] || uso
[ "$(id -u)" -eq 0 ] || erro "rode com sudo."
case "$VERSAO" in 14|15|16|18) ;; *) erro "VERSAO deve ser 14, 15, 16 ou 18." ;; esac
[[ "$PORTA" =~ ^[0-9]+$ ]] && [ "$PORTA" -ge 1024 ] && [ "$PORTA" -le 65535 ] || erro "use uma porta entre 1024 e 65535."
[ -z "$BASE" ] || [[ "$BASE" =~ ^[a-zA-Z0-9_]+$ ]] || erro "nome da base: use só letras, números e _."
[ ! -e "$DESTINO" ] || erro "a pasta $DESTINO já existe."
porta_ocupada "$PORTA" && erro "a porta $PORTA já está em uso."
if [ -n "$DOMINIO" ]; then
  [[ "$DOMINIO" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || erro "domínio inválido: $DOMINIO"
  for p in 80 443; do
    porta_ocupada "$p" && erro "a porta $p já está em uso; com DOMINIO, as portas 80 e 443 precisam estar livres."
  done
fi

# Docker, git e openssl: instala automaticamente no Ubuntu/Debian se faltarem
# (repositório oficial do Docker, conforme docs.docker.com/engine/install).
instalar_dependencias() {
  . /etc/os-release
  case "${ID:-}" in ubuntu|debian) ;; *)
    erro "instale o Docker manualmente (https://docs.docker.com/engine/install/) e rode de novo." ;;
  esac
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get install -y -q ca-certificates curl git openssl
  if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
    echo ">> Instalando o Docker (repositório oficial)"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc \
      || erro "não foi possível acessar download.docker.com; verifique a internet do servidor."
    chmod a+r /etc/apt/keyrings/docker.asc
    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/$ID
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    apt-get update -q
    apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker >/dev/null 2>&1 || true
  fi
}
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1 \
   || ! command -v git >/dev/null || ! command -v openssl >/dev/null; then
  echo ">> Instalando os programas necessários (Docker, git)"
  instalar_dependencias </dev/null
fi
DC=(docker compose)

gerar() { openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-"$1"; }

echo ">> Baixando o projeto ($REF) em $DESTINO"
git clone -q --depth=1 -b "$REF" "$REPO" "$DESTINO"
rm -rf "$DESTINO/.git"
cd "$DESTINO"

echo ">> Gerando senhas e configuração"
umask 077
mkdir -p postgresql secrets addons proxy/data proxy/config
gerar 32 > secrets/db_password.txt
SENHA_MESTRA=$(gerar 24)
GESTOR_USUARIO="gestor"
GESTOR_SENHA=$(gerar 20)
sed -e "s|__ADMIN_PASSWD__|$SENHA_MESTRA|" etc/odoo.conf.example > etc/odoo.conf
PROJETO=$(basename "$DESTINO" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n_-' '_')
{
  echo "COMPOSE_PROJECT_NAME=$PROJETO"
  if [ -n "$DOMINIO" ]; then
    echo "COMPOSE_FILE=docker-compose.yml:docker-compose.https.yml"
    echo "HTTP_PORT=80"
  else
    echo "HTTP_PORT=$PORTA"
  fi
  echo "ODOO_IMAGE=$ODOO_IMAGE"
  echo "POSTGRES_IMAGE=${POSTGRES_IMAGE:-postgres:16}"
  echo "CADDY_IMAGE=$CADDY_IMAGE"
} > .env
umask 022

echo ">> Ajuste do sistema (inotify, para várias instâncias)"
echo "fs.inotify.max_user_watches = 524288" > /etc/sysctl.d/90-odoo-inotify.conf
sysctl -q -p /etc/sysctl.d/90-odoo-inotify.conf || true

echo ">> Baixando a imagem do Odoo $VERSAO"
docker pull -q "$ODOO_IMAGE" </dev/null >/dev/null
if [ -z "$POSTGRES_IMAGE" ]; then
  # O backup do Gerenciador usa o pg_dump da imagem do Odoo, que não aceita
  # servidor PostgreSQL mais novo que ele: escolhe a versão compatível (máx. 16).
  PGCLI=$(docker run --rm --entrypoint pg_dump "$ODOO_IMAGE" --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
  [[ "$PGCLI" =~ ^[0-9]+$ ]] || PGCLI=16
  [ "$PGCLI" -gt 16 ] && PGCLI=16
  POSTGRES_IMAGE="postgres:$PGCLI"
  sed -i "s|^POSTGRES_IMAGE=.*|POSTGRES_IMAGE=$POSTGRES_IMAGE|" .env
fi
echo "   PostgreSQL: $POSTGRES_IMAGE"

echo ">> Baixando as demais imagens e fixando as versões (digest)"
"${DC[@]}" pull -q </dev/null
for var in ODOO_IMAGE POSTGRES_IMAGE CADDY_IMAGE; do
  img=$(grep "^$var=" .env | cut -d= -f2-)
  dig=$(docker image inspect --format '{{index .RepoDigests 0}}' "$img" 2>/dev/null || true)
  [ -n "$dig" ] && sed -i "s|^$var=.*|$var=$dig|" .env
done
IMG_ODOO=$(grep '^ODOO_IMAGE=' .env | cut -d= -f2-)
IMG_CADDY=$(grep '^CADDY_IMAGE=' .env | cut -d= -f2-)

echo ">> Configurando o proxy (Caddy)"
# A senha vai pela entrada padrão (duas vezes: senha e confirmação), não pela linha de comando.
GESTOR_HASH=$(printf '%s\n%s\n' "$GESTOR_SENHA" "$GESTOR_SENHA" | docker run --rm -i "$IMG_CADDY" caddy hash-password 2>/dev/null | tail -1)
[[ "$GESTOR_HASH" == \$2* ]] || erro "não foi possível gerar o hash da senha do gerenciador."
ENDERECO=":80"; [ -n "$DOMINIO" ] && ENDERECO="$DOMINIO"
cat > proxy/Caddyfile <<EOF
# Gerado pelo instalar.sh — instância $DESTINO (Odoo $VERSAO)
{
	admin off
	${EMAIL:+email $EMAIL}
}

$ENDERECO {
	encode gzip

	# Gerenciador de Bancos e serviço de bancos da API: exigem o usuário e a
	# senha abaixo (proxy) e, depois, a senha mestra do Odoo. O /jsonrpc entra
	# aqui porque também aceita operações de banco (criar, copiar, excluir).
	# A escolha da base no login e a API XML-RPC (common/object) ficam livres.
	@gestor path /web/database/manager /web/database/create /web/database/duplicate /web/database/drop /web/database/backup /web/database/restore /web/database/change_password /xmlrpc/db /xmlrpc/2/db /jsonrpc
	basic_auth @gestor {
		$GESTOR_USUARIO $GESTOR_HASH
	}

	# Live chat e notificações: /longpolling (Odoo 14 e 15) e /websocket (Odoo 16 e 18).
	handle /longpolling/* {
		reverse_proxy odoo:8072
	}
	handle /websocket* {
		reverse_proxy odoo:8072
	}
	handle {
		reverse_proxy odoo:8069
	}
}
EOF
docker run --rm -v "$PWD/proxy/Caddyfile:/etc/caddy/Caddyfile:ro" "$IMG_CADDY" \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 \
  || erro "configuração do proxy inválida (proxy/Caddyfile)."

echo ">> Permissões (sem 777; o Odoo roda sem root)"
OUID=$(docker run --rm --entrypoint id "$IMG_ODOO" -u)
OGID=$(docker run --rm --entrypoint id "$IMG_ODOO" -g)
chown -R "$OUID:$OGID" etc addons secrets/db_password.txt
chmod 750 etc addons
chmod 640 etc/odoo.conf
chmod 400 secrets/db_password.txt
chmod 700 secrets
chmod 600 .env proxy/Caddyfile

echo ">> Iniciando o PostgreSQL"
"${DC[@]}" up -d db </dev/null
for _ in $(seq 1 60); do
  "${DC[@]}" exec -T db pg_isready -U odoo -q </dev/null 2>/dev/null && break
  sleep 1
done
"${DC[@]}" exec -T db pg_isready -U odoo -q </dev/null || erro "o PostgreSQL não respondeu."

SENHA_ADMIN=""
if [ -n "$BASE" ]; then
  echo ">> Criando a base '$BASE' (sem dados de demonstração, em português)"
  "${DC[@]}" run --rm -T odoo odoo -d "$BASE" -i base --without-demo=all \
      --load-language=pt_BR --stop-after-init --no-http </dev/null
  SENHA_ADMIN=$(gerar 16)
  printf "u = env.ref('base.user_admin')\nu.password = '%s'\nu.lang = 'pt_BR'\nenv.cr.commit()\n" "$SENHA_ADMIN" \
    | "${DC[@]}" run --rm -T odoo odoo shell -d "$BASE" --no-http >/dev/null
fi

echo ">> Iniciando o Odoo e o proxy"
"${DC[@]}" up -d </dev/null

if [ -n "$DOMINIO" ]; then
  URL="https://$DOMINIO"
  TESTE=(curl -sk --resolve "$DOMINIO:443:127.0.0.1" -o /dev/null -w '%{http_code}' "$URL/web/database/selector")
else
  IP=$(curl -fsS --max-time 3 http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null \
       || hostname -I | awk '{print $1}')
  URL="http://$IP:$PORTA"
  TESTE=(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORTA/web/database/selector")
fi

echo ">> Aguardando o Odoo responder"
ok=0
for _ in $(seq 1 90); do
  [ "$("${TESTE[@]}" 2>/dev/null || true)" = "200" ] && { ok=1; break; }
  sleep 2
done

umask 077
{
  echo "Instância: $DESTINO   Odoo $VERSAO   (gerado em $(date '+%F %T'))"
  echo "Acesso: $URL"
  echo "Gerenciador de Bancos: $URL/web/database/manager"
  echo "  1º usuário/senha (proxy): $GESTOR_USUARIO / $GESTOR_SENHA"
  echo "  2º senha mestra (Odoo):   $SENHA_MESTRA"
  if [ -n "$BASE" ]; then
    echo "Base inicial: $BASE   usuário: admin   senha: $SENHA_ADMIN"
  fi
  echo "Senha do PostgreSQL: arquivo secrets/db_password.txt"
} > .credenciais
umask 022

echo
echo "=============================================================="
if [ "$ok" = "1" ]; then echo " Odoo $VERSAO pronto"; else echo " Odoo $VERSAO iniciado (ainda carregando; aguarde 1 minuto)"; fi
echo
echo "   Acesse:                $URL"
echo "   Gerenciador de Bancos: $URL/web/database/manager"
echo "     usuário do proxy:    $GESTOR_USUARIO"
echo "     senha do proxy:      $GESTOR_SENHA"
echo "     senha mestra:        $SENHA_MESTRA"
if [ -n "$BASE" ]; then
  echo "   Base '$BASE':  usuário admin / senha $SENHA_ADMIN"
else
  echo
  echo "   Primeiro passo: abra o Gerenciador de Bancos e crie uma base."
fi
echo
echo "   Para ver estes dados de novo: sudo cat $(pwd)/.credenciais"
echo "=============================================================="
if [ -z "$DOMINIO" ]; then
  echo "Acesso por HTTP, sem criptografia: use para testes. Para produção,"
  echo "reinstale com DOMINIO=seu.dominio (HTTPS automático)."
  echo "Libere a porta $PORTA no firewall de nuvem do provedor, se houver."
else
  echo "Libere as portas 80 e 443 no firewall de nuvem do provedor, se houver."
  [ "$ok" = "1" ] || echo "Se o HTTPS não abrir, confira se $DOMINIO aponta para este servidor: sudo docker compose logs proxy"
fi
