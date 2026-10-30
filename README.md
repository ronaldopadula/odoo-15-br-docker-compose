# Em primeiro lugar:
Fork criado apenas para utilização em demonstração. Tradução ao Português com todos os créditos ao criador do código.

# Odoo 15 com Docker Compose — instalação simples, interfaces disponíveis e segura

Instala uma instância do Odoo 15 com um comando. Cada instância tem sua porta, atende várias bases
de dados e oferece o **Gerenciador de Bancos** pelo navegador (criar, duplicar, fazer backup e
restaurar bases). Suporta várias instâncias na mesma máquina.

> **Aviso:** o Odoo 15 não recebe mais correções. O último commit do branch 15.0 do Odoo é de 14/10/2024,
> e a imagem `odoo:15.0` foi retirada do repositório oficial de imagens (odoo/docker) em 07/10/2024.
> Em produção, use sempre com domínio e HTTPS.

## Como funciona

```
navegador ──> proxy Caddy (porta da instância) ──> Odoo ──> PostgreSQL
```

Só o proxy recebe conexões de fora. O Odoo e o PostgreSQL ficam numa rede interna do Docker.

| Item | Como fica |
|---|---|
| Acesso | `http://IP:PORTA` (teste) ou `https://seu.dominio` com certificado automático (produção) |
| Bases de dados | várias por instância; o usuário escolhe a base no login |
| Gerenciador de Bancos | `…/web/database/manager`, protegido por **duas senhas**: a do proxy (usuário `gestor`) e a senha mestra do Odoo |
| Live chat / notificações | encaminhados pelo proxy, sem porta extra |
| Senhas | todas aleatórias, geradas na instalação e exibidas no final; nada fica no repositório |
| Contêineres | Odoo roda sem root; sem `chmod 777`; imagens fixadas por *digest* |

## Requisitos

Linux com Docker e o plugin Compose. No Ubuntu, conforme a documentação oficial do Docker:

``` bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git
```

## Instalação

Baixe o instalador, confira e execute:

``` bash
curl -fsSLO https://raw.githubusercontent.com/ronaldopadula/odoo-15-br-docker-compose/master/instalar.sh
less instalar.sh
```

**Teste, pelo IP do servidor:**

``` bash
sudo bash instalar.sh odoo15-one 10015
```

**Produção, com domínio e HTTPS automático** (o domínio deve apontar para o servidor, e as portas
80 e 443 devem estar livres):

``` bash
sudo DOMINIO=erp.seudominio.com.br EMAIL=ti@seudominio.com.br bash instalar.sh odoo15-prod 10015
```

Argumentos: `<pasta> <porta> [base_inicial]`. Se informar `base_inicial`, a base já é criada, com senha
aleatória para o usuário `admin`. Sem ela, crie as bases pelo Gerenciador de Bancos.

Ao final, o instalador mostra tudo o que é preciso:

```
==============================================================
 Odoo 15 pronto

   Acesse:                http://IP:10015
   Gerenciador de Bancos: http://IP:10015/web/database/manager
     usuário do proxy:    gestor
     senha do proxy:      (gerada)
     senha mestra:        (gerada)
==============================================================
```

Esses dados ficam guardados em `<pasta>/.credenciais` (só o root lê):

``` bash
sudo cat odoo15-one/.credenciais
```

**Firewall:** se o provedor tiver firewall de nuvem (ex.: DigitalOcean › Networking › Firewalls),
libere a porta da instância — ou 80 e 443, no modo com domínio.

## Gerenciador de Bancos

Abra `…/web/database/manager`. O navegador pede **usuário e senha do proxy** (`gestor` e a senha
gerada); em seguida, cada operação pede a **senha mestra** do Odoo. A tela de escolha de base, no
login, continua livre para os usuários.

No modo por IP, a conexão não é criptografada — use para testes. Em produção, use o modo com domínio.

## Várias instâncias na mesma máquina

Cada instância usa uma pasta e uma porta próprias:

``` bash
sudo bash instalar.sh odoo15-one 10015
sudo bash instalar.sh odoo15-two 11015
```

Apenas **uma** instância por servidor pode usar o modo com domínio, porque ele ocupa as portas 80 e 443.

## Administração

Dentro da pasta da instância:

``` bash
sudo docker compose up -d          # iniciar
sudo docker compose restart        # reiniciar
sudo docker compose down           # parar
sudo docker compose logs -f odoo15 # log do Odoo (também em etc/odoo-server.log)
sudo docker compose logs -f proxy  # log do proxy / certificado HTTPS
```

## Backup e restauração

Pelo navegador: Gerenciador de Bancos › *Backup* / *Restore*.

Pelo console (útil para bases grandes ou rotinas automáticas):

``` bash
cd odoo15-one
sudo docker compose exec -T db pg_dump -U odoo -Fc NOME_DA_BASE > backup.dump
sudo tar -czf filestore.tar.gz -C etc/filestore NOME_DA_BASE

# restaurar
sudo docker compose exec -T db createdb -U odoo NOME_DA_BASE
sudo docker compose exec -T db pg_restore -U odoo -d NOME_DA_BASE --no-owner --no-privileges < backup.dump
```

O PostgreSQL padrão é o 16; um dump gerado no 16 não pode ser restaurado num servidor 14.
Para usar o 14, instale com `POSTGRES_IMAGE=postgres:14`.

## Custom addons

Coloque os módulos na pasta `addons/` da instância e reinicie o Odoo.
Pacotes Python extras: liste em `etc/requirements.txt` e descomente a linha do `entrypoint.sh` no `docker-compose.yml`.

## Restringir uma instância a uma única base

Em `etc/odoo.conf`, troque `list_db = True` por `list_db = False` e defina `dbfilter = ^nome_da_base$`.
Reinicie o Odoo. O Gerenciador de Bancos deixa de funcionar nessa instância.

## Instalações feitas com versões anteriores deste repositório

- **Versão original:** a senha mestra era fixa e pública (continua visível no histórico do Git).
  Troque `admin_passwd` em `etc/odoo.conf` e não publique as portas 8069/8072 do Odoo diretamente.
- **Versões com Nginx (outubro/2026):** continuam funcionando. Para migrar, faça backup das bases,
  instale uma instância nova com esta versão e restaure as bases nela.

## Odoo 15 screenshots

<img src="screenshots/odoo-15-welcome-screenshot.png" width="50%">

<img src="screenshots/odoo-15-apps-screenshot.png" width="100%">

<img src="screenshots/odoo-15-sales-screen.png" width="100%">

<img src="screenshots/odoo-15-product-form.png" width="100%">
