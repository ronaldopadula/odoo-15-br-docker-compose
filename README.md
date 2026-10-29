# Em primeiro lugar:
Fork criado apenas para utilização em demonstração. Tradução ao Português com todos os créditos ao criador do código.

# Odoo 15 com Docker Compose — instalação simplificada e segura

Instala uma instância do Odoo 15 com um comando. Suporta várias instâncias na mesma máquina, cada uma na sua pasta.

> **Aviso:** o Odoo 15 não recebe mais correções. O último commit do branch 15.0 do Odoo é de 14/10/2024,
> e a imagem `odoo:15.0` foi retirada do repositório oficial de imagens (odoo/docker) em 07/10/2024.
> Use atrás de HTTPS, com senhas fortes e acesso restrito.

## O que esta versão faz por segurança

| Antes | Agora |
|---|---|
| Senha mestra fixa e publicada no repositório | senha mestra aleatória, gerada na instalação |
| Senha do banco fixa no `docker-compose.yml` | senha aleatória em `secrets/db_password.txt` (docker secret) |
| Gerenciador de bancos aberto (`/web/database/manager`) | `list_db = False` e `dbfilter` restrito à base da instância |
| Porta do Odoo aberta para a internet | publicada só em `127.0.0.1`; acesso externo pelo Nginx com HTTPS |
| `chmod -R 777` e contêineres como `root` | o Odoo roda como usuário `odoo`; arquivos com permissões restritas |
| `dev_mode = reload` (modo de desenvolvimento) | modo de produção, com `workers` e `proxy_mode` |
| Imagens sem versão fixa | o instalador grava o *digest* das imagens no `.env` |
| Usuário `admin` com senha `admin` na base nova | senha aleatória para o `admin` |

Nenhuma senha fica no repositório: `.env`, `secrets/`, `etc/odoo.conf` e `.credenciais` são gerados em cada
instalação e estão no `.gitignore`.

## Requisitos

- Linux com [Docker](https://docs.docker.com/engine/install/) e o plugin Compose (`docker compose`)
- `git` e `openssl`
- Nginx e Certbot, para publicar com HTTPS

## Instalação

Recomendado: baixe, leia e só então execute.

``` bash
curl -fsSLO https://raw.githubusercontent.com/ronaldopadula/odoo-15-br-docker-compose/master/instalar.sh
less instalar.sh
sudo bash instalar.sh odoo15-one 10015 20015 empresa
```

Argumentos:
* **odoo15-one**: pasta da instância
* **10015**: porta local do Odoo
* **20015**: porta local do live chat
* **empresa** (opcional, padrão `odoo`): nome da base de dados criada

As senhas geradas ficam em `odoo15-one/.credenciais`, legível só pelo root:

``` bash
sudo cat odoo15-one/.credenciais
```

Segunda instância na mesma máquina: use outra pasta e outras portas, por exemplo
`sudo bash instalar.sh odoo15-two 11015 21015 outraempresa`.

## Acesso

O Odoo atende só em `127.0.0.1`. Há duas formas de acessar:

**Servidor na internet (produção):** configure o Nginx com o modelo [`nginx/odoo.conf.example`](nginx/odoo.conf.example)
e emita o certificado com `certbot --nginx -d SEU_DOMINIO --redirect`. Acesse por `https://SEU_DOMINIO`.

**Teste rápido sem domínio:** abra um túnel SSH do seu computador e acesse `http://localhost:10015`:

``` bash
ssh -L 10015:127.0.0.1:10015 usuario@IP_DO_SERVIDOR
```

## Administração

Dentro da pasta da instância:

``` bash
sudo docker compose up -d        # iniciar
sudo docker compose restart      # reiniciar
sudo docker compose down         # parar
sudo docker compose logs -f odoo15
```

O log do Odoo também fica em `etc/odoo-server.log`.

## Restaurar uma base existente (dump)

Instale sem criar base, informando o nome da base que será restaurada:

``` bash
sudo CRIAR_BASE=0 bash instalar.sh minha-instancia 10015 20015 nome_da_base
cd minha-instancia
sudo docker compose stop odoo15
sudo docker compose exec -T db createdb -U odoo nome_da_base
sudo docker compose exec -T db pg_restore -U odoo -d nome_da_base --no-owner --no-privileges < /caminho/backup.dump
sudo docker compose start odoo15
```

Os anexos (filestore) vão para `etc/filestore/nome_da_base/`, com o mesmo dono da pasta `etc`.

O PostgreSQL padrão é o 16. Um dump gerado no 16 não pode ser restaurado num servidor 14.
Para manter o 14, instale com `POSTGRES_IMAGE=postgres:14`.

## Custom addons

Coloque os módulos próprios na pasta `addons/` da instância e reinicie o Odoo.
Pacotes Python extras: liste em `etc/requirements.txt` e descomente a linha do `entrypoint.sh` no `docker-compose.yml`.

## Instalações feitas com a versão anterior deste repositório

A versão anterior publicava a senha mestra no próprio repositório, e ela continua visível no histórico do Git.
Em toda instância já instalada:

1. **Troque já a senha mestra** (`admin_passwd`) em `etc/odoo.conf` e reinicie o Odoo.
2. Acrescente `list_db = False` e `dbfilter = ^nome_da_base$` ao `etc/odoo.conf`.
3. No `docker-compose.yml`, troque `"10015:8069"` por `"127.0.0.1:10015:8069"` (idem para a porta do chat)
   e publique pelo Nginx com HTTPS.
4. Troque a senha do PostgreSQL e remova o `chmod 777` das pastas.
5. Mantenha `postgres:14` nessas instâncias: os dados de um PostgreSQL 14 não abrem diretamente no 16.

## Odoo 15 screenshots

<img src="screenshots/odoo-15-welcome-screenshot.png" width="50%">

<img src="screenshots/odoo-15-apps-screenshot.png" width="100%">

<img src="screenshots/odoo-15-sales-screen.png" width="100%">

<img src="screenshots/odoo-15-product-form.png" width="100%">
