#!/bin/bash
# Entrypoint opcional: igual ao da imagem oficial do Odoo 15, mais a instalação
# dos pacotes listados em etc/requirements.txt. Para usar, descomente a linha
# "./entrypoint.sh:/entrypoint.sh" no docker-compose.yml.

set -e

# Senha do banco lida de arquivo (docker secret), nunca fixa no código.
if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< "$PASSWORD_FILE")"
fi

: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:?defina PASSWORD_FILE ou PASSWORD}}}

# Pacotes Python extras (instalados no perfil do usuário odoo; o contêiner não roda como root).
if grep -qvE '^\s*(#|$)' /etc/odoo/requirements.txt 2>/dev/null; then
    pip3 install --user --no-cache-dir -q -r /etc/odoo/requirements.txt
fi

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py "${DB_ARGS[@]}" --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py "${DB_ARGS[@]}" --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
