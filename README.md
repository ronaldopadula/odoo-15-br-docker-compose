# Em primeiro lugar:
Fork criado apenas para utilização em demonstração. Tradução ao Português com todos os créditos ao criador do código.

# Odoo 15 em um comando

Instala o Odoo 15 num servidor Linux (Ubuntu ou Debian) com **um único comando**.
Ao final, o instalador mostra o endereço de acesso e todas as senhas.

> O Odoo 15 não recebe mais atualizações de segurança do fabricante desde outubro de 2024.
> Para uso real, siga o passo **"Usar com domínio (HTTPS)"** mais abaixo.

---

## Instalação em 3 passos

### 1. Entre no servidor

Pelo console do provedor (ex.: DigitalOcean › *Droplet* › *Console*) ou por SSH:

``` bash
ssh root@IP_DO_SERVIDOR
```

### 2. Rode o instalador

``` bash
curl -fsSLO https://raw.githubusercontent.com/ronaldopadula/odoo-15-br-docker-compose/master/instalar.sh
sudo bash instalar.sh odoo15-one 10015
```

- `odoo15-one` é o nome da pasta onde a instalação fica guardada.
- `10015` é a porta de acesso.

O instalador faz tudo sozinho: instala o Docker (se precisar), gera as senhas e liga o Odoo.
Leva de 3 a 10 minutos.

### 3. Abra no navegador

No final aparece um quadro assim:

```
==============================================================
 Odoo 15 pronto

   Acesse:                http://IP_DO_SERVIDOR:10015
   Gerenciador de Bancos: http://IP_DO_SERVIDOR:10015/web/database/manager
     usuário do proxy:    gestor
     senha do proxy:      ••••••••
     senha mestra:        ••••••••
==============================================================
```

Abra o endereço **Gerenciador de Bancos** e crie a sua primeira base de dados.
Depois é só acessar o endereço **Acesse**.

> **Não abriu?** O provedor provavelmente tem um firewall. Na DigitalOcean:
> *Networking › Firewalls* › regra de entrada liberando a porta **10015** (TCP).

---

## Perguntas frequentes

### Perdi as senhas. Como vejo de novo?

``` bash
sudo cat odoo15-one/.credenciais
```

### O que é o "Gerenciador de Bancos" e por que ele pede duas senhas?

É a tela do Odoo para **criar, copiar, fazer backup, restaurar e excluir** bases de dados.
Como ela dá acesso a todos os dados, tem duas proteções:

1. o navegador pede **usuário e senha do proxy** (usuário `gestor`);
2. cada operação pede a **senha mestra** do Odoo.

Os dois estão no quadro final e no arquivo `.credenciais`.

### Posso ter várias empresas/bases?

Sim. Crie quantas bases quiser no Gerenciador de Bancos. Na tela de login, cada usuário escolhe a base.

### Posso instalar mais de um Odoo no mesmo servidor?

Sim, com outra pasta e outra porta:

``` bash
sudo bash instalar.sh odoo15-two 11015
```

### Usar com domínio (HTTPS) — recomendado para uso real

1. No seu provedor de domínio, crie um registro **tipo A** apontando, por exemplo,
   `erp.seudominio.com.br` para o IP do servidor.
2. No firewall do provedor de nuvem, libere as portas **80** e **443**.
3. Instale assim:

``` bash
sudo DOMINIO=erp.seudominio.com.br bash instalar.sh odoo15-prod 10015
```

O endereço passa a ser `https://erp.seudominio.com.br`, com certificado gratuito, emitido e
renovado automaticamente. Só uma instalação por servidor pode usar domínio.

### Quero já criar uma base na instalação

Acrescente o nome da base no final do comando:

``` bash
sudo bash instalar.sh odoo15-one 10015 minhaempresa
```

O quadro final mostra o usuário `admin` e a senha dessa base.

### Como faço backup?

Pelo navegador: **Gerenciador de Bancos › Backup**. O arquivo baixado inclui a base e os anexos.

### Como ligo, desligo ou reinicio?

Dentro da pasta da instalação (`cd odoo15-one`):

| Ação | Comando |
|---|---|
| Ligar | `sudo docker compose up -d` |
| Desligar | `sudo docker compose down` |
| Reiniciar | `sudo docker compose restart` |
| Ver o que está acontecendo (log) | `sudo docker compose logs -f odoo15` |

O Odoo volta a ligar sozinho se o servidor reiniciar.

### Como instalo módulos extras (addons)?

Copie as pastas dos módulos para `odoo15-one/addons/`, rode `sudo docker compose restart` e,
no Odoo, vá em *Aplicativos › Atualizar lista de aplicativos*.

---

## Detalhes técnicos

<details>
<summary>Como a instalação é montada</summary>

```
navegador ──> proxy Caddy (porta da instância) ──> Odoo 15 ──> PostgreSQL 16
```

- Só o proxy recebe conexões de fora. Odoo e PostgreSQL ficam numa rede interna do Docker, sem portas publicadas.
- O proxy encaminha o live chat (longpolling) e protege as rotas do Gerenciador de Bancos com `basic_auth`.
- Com `DOMINIO`, o Caddy obtém e renova o certificado HTTPS (Let's Encrypt).
- Senhas aleatórias geradas na instalação; o Odoo roda sem root; imagens fixadas por *digest* no `.env`.
- Arquivos de cada instalação (não versionados): `.env`, `.credenciais`, `secrets/`, `etc/odoo.conf`, `proxy/`, `postgresql/`.

</details>

<details>
<summary>Opções do instalador</summary>

``` bash
sudo bash instalar.sh <pasta> <porta> [base_inicial]
```

| Variável | Para quê |
|---|---|
| `DOMINIO=erp.exemplo.com.br` | publica com HTTPS automático |
| `EMAIL=ti@exemplo.com.br` | contato para avisos do certificado (opcional) |
| `POSTGRES_IMAGE=postgres:14` | usar PostgreSQL 14 (padrão: 16) |
| `REF=<branch>` | instalar outra versão deste repositório |

</details>

<details>
<summary>Backup e restauração pelo console (bases grandes)</summary>

``` bash
cd odoo15-one
sudo docker compose exec -T db pg_dump -U odoo -Fc NOME_DA_BASE > backup.dump
sudo tar -czf filestore.tar.gz -C etc/filestore NOME_DA_BASE

sudo docker compose exec -T db createdb -U odoo NOME_DA_BASE
sudo docker compose exec -T db pg_restore -U odoo -d NOME_DA_BASE --no-owner --no-privileges < backup.dump
```

Um dump gerado no PostgreSQL 16 não pode ser restaurado num servidor 14.

</details>

<details>
<summary>Restringir a instalação a uma única base</summary>

Em `etc/odoo.conf`, troque `list_db = True` por `list_db = False`, acrescente `dbfilter = ^nome_da_base$`
e reinicie. O Gerenciador de Bancos deixa de funcionar nessa instalação.

</details>

<details>
<summary>Pacotes Python extras</summary>

Liste os pacotes em `etc/requirements.txt` (ex.: `openupgradelib`, exigido pela localização brasileira
da Trustcode), descomente a linha do `entrypoint.sh` no `docker-compose.yml` e reinicie.

</details>

<details>
<summary>Instalações feitas com versões anteriores deste repositório</summary>

- **Versão original:** a senha mestra era fixa e pública (continua visível no histórico do Git).
  Troque `admin_passwd` em `etc/odoo.conf` e não deixe as portas do Odoo abertas diretamente.
- **Versões com Nginx (outubro/2026):** continuam funcionando. Para migrar, faça backup das bases,
  instale com esta versão e restaure.

</details>

## Odoo 15 screenshots

<img src="screenshots/odoo-15-welcome-screenshot.png" width="50%">

<img src="screenshots/odoo-15-apps-screenshot.png" width="100%">

<img src="screenshots/odoo-15-sales-screen.png" width="100%">

<img src="screenshots/odoo-15-product-form.png" width="100%">
