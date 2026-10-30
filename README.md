# Em primeiro lugar:
Fork criado apenas para utilização em demonstração. Tradução ao Português com todos os créditos ao criador do código.

# Odoo 14, 15, 16 ou 18 em um comando

Instala o Odoo (versão 14, 15, 16 ou 18) num servidor Linux (Ubuntu ou Debian) com **um único comando**.
Ao final, o instalador mostra o endereço de acesso e todas as senhas.

> Das versões disponíveis, só a **18** ainda tem imagem oficial mantida pela Odoo. As versões 14, 15
> e 16 tiveram as imagens retiradas em nov/2023, out/2024 e set/2025, respectivamente. Para uso real,
> siga o passo **"Usar com domínio (HTTPS)"** mais abaixo.

---

## Instalação passo a passo

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
- Sem indicar a versão, instala o **Odoo 15**. Para outra versão, use `VERSAO`:

``` bash
sudo VERSAO=18 bash instalar.sh odoo18 10018   # Odoo 18
sudo VERSAO=16 bash instalar.sh odoo16 10016   # Odoo 16
sudo VERSAO=14 bash instalar.sh odoo14 10014   # Odoo 14
```

O instalador faz tudo sozinho: instala o Docker (se precisar), gera as senhas e liga o Odoo.
Leva de 3 a 10 minutos.

### 3. Guarde os dados do quadro final

No final aparece um quadro com os endereços e as senhas:

```
==============================================================
 Odoo 15 pronto      (ou 14 / 16, conforme a versão)

   Acesse:                http://IP_DO_SERVIDOR:10015
   Gerenciador de Bancos: http://IP_DO_SERVIDOR:10015/web/database/manager
     usuário do proxy:    gestor
     senha do proxy:      ••••••••
     senha mestra:        ••••••••
==============================================================
```

### 4. Crie a sua primeira base de dados

Abra o endereço do **Gerenciador de Bancos**. O navegador pede um usuário e uma senha:
digite **`gestor`** e a **senha do proxy** mostrada no quadro.

> **Não abriu?** O provedor provavelmente tem um firewall. Na DigitalOcean:
> *Networking › Firewalls* › regra de entrada liberando a porta **10015** (TCP).

<img src="screenshots/1-senha-do-gerenciador.png" width="600" alt="Janela de usuário e senha do navegador">

> O aviso "conexão não é particular" aparece porque o acesso pelo IP não tem criptografia.
> Ele some quando você usa um domínio (veja *Usar com domínio (HTTPS)*).

Em seguida aparece o formulário de criação da base. Ele é do próprio Odoo e vem em inglês
(as imagens são do Odoo 15; nas outras versões as telas são parecidas):

<img src="screenshots/2-criar-base.png" width="380" alt="Formulário de criação de base do Odoo">

| Campo | O que preencher |
|---|---|
| **Master Password** | a **senha mestra** mostrada no quadro final |
| **Database Name** | nome da base, sem espaços nem acentos (ex.: `minhaempresa`) |
| **Email** | o login do administrador da base (pode ser o seu e-mail) |
| **Password** | a senha do administrador — **anote**, é com ela que você vai entrar |
| **Phone number** | opcional |
| **Language** | `Portuguese (BR) / Português (BR)` |
| **Country** | `Brazil` |
| **Demo data** | **deixe desmarcado** (marcado, a base vem cheia de dados fictícios) |

Clique em **Create database** e aguarde cerca de 1 minuto.

### 5. Entre no Odoo

Abra o endereço **Acesse**. Se houver mais de uma base, escolha qual abrir:

<img src="screenshots/4-escolher-base.png" width="380" alt="Tela de escolha da base de dados">

Entre com o e-mail e a senha que você definiu no formulário:

<img src="screenshots/5-login.png" width="260" alt="Tela de login do Odoo em português">

Pronto. A tela inicial mostra os aplicativos que você pode instalar (Vendas, Compras, Estoque,
Contabilidade etc.):

<img src="screenshots/6-aplicativos.png" width="700" alt="Tela de aplicativos do Odoo em português">

> Os botões **Upgrade** são de recursos da versão paga (Enterprise), que não fazem parte desta
> instalação. Use os aplicativos com o botão **Instalar**.

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

Sim, inclusive de versões diferentes. Cada um com sua pasta e sua porta:

``` bash
sudo bash instalar.sh odoo15-two 11015
sudo VERSAO=16 bash instalar.sh odoo16 10016
```

### Qual versão escolher?

| Versão | Quando usar |
|---|---|
| **18** | **instalações novas**: única das quatro com suporte da Odoo (imagem oficial mantida) |
| **16** | bases existentes na versão 16 |
| **15** | padrão deste projeto; use se já tem bases na versão 15 |
| **14** | apenas para abrir ou manter bases antigas da versão 14 |

Uma base só abre na mesma versão em que foi criada. Passar uma base de uma versão para outra
(migração) é um processo à parte, que não é feito por este instalador.

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

Pelo navegador, no **Gerenciador de Bancos**:

<img src="screenshots/3-gerenciador.png" width="380" alt="Gerenciador de Bancos com as opções Backup, Duplicate e Delete">

| Botão | Para quê |
|---|---|
| **Backup** | baixa uma cópia da base (escolha o formato *zip*: inclui os anexos) |
| **Duplicate** | cria uma cópia da base no servidor (útil para testes) |
| **Delete** | exclui a base — **não tem volta** |
| **Restore Database** | carrega um backup baixado antes |
| **Set Master Password** | troca a senha mestra |

Todas as operações pedem a senha mestra.

### Como ligo, desligo ou reinicio?

Dentro da pasta da instalação (`cd odoo15-one`):

| Ação | Comando |
|---|---|
| Ligar | `sudo docker compose up -d` |
| Desligar | `sudo docker compose down` |
| Reiniciar | `sudo docker compose restart` |
| Ver o que está acontecendo (log) | `sudo docker compose logs -f odoo` |

O Odoo volta a ligar sozinho se o servidor reiniciar.

### Como instalo módulos extras (addons)?

Copie as pastas dos módulos para `odoo15-one/addons/`, rode `sudo docker compose restart` e,
no Odoo, vá em *Aplicativos › Atualizar lista de aplicativos*.

---

## Detalhes técnicos

<details>
<summary>Como a instalação é montada</summary>

```
navegador ──> proxy Caddy (porta da instância) ──> Odoo 14/15/16/18 ──> PostgreSQL
```

- Só o proxy recebe conexões de fora. Odoo e PostgreSQL ficam numa rede interna do Docker, sem portas publicadas.
- O proxy encaminha o live chat (`/longpolling` no 14/15, `/websocket` no 16/18) e protege com `basic_auth`
  as rotas do Gerenciador de Bancos e do serviço de bancos da API (`/xmlrpc/db`, `/xmlrpc/2/db`, `/jsonrpc`).
- A API XML-RPC (`/xmlrpc/2/common`, `/xmlrpc/2/object`) continua livre para integrações.
  Integrações via JSON-RPC (`/jsonrpc`) precisam do usuário e senha do proxy.
- O PostgreSQL é escolhido conforme o `pg_dump` da imagem do Odoo (até o 16), para que o
  backup pelo Gerenciador funcione.
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
| `VERSAO=14`, `15`, `16` ou `18` | versão do Odoo (padrão: 15) |
| `DOMINIO=erp.exemplo.com.br` | publica com HTTPS automático |
| `EMAIL=ti@exemplo.com.br` | contato para avisos do certificado (opcional) |
| `POSTGRES_IMAGE=postgres:14` | fixar outra versão do PostgreSQL (padrão: automática) |
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

Um dump gerado num PostgreSQL mais novo não pode ser restaurado num servidor mais antigo
(ex.: dump do 16 num servidor 13).

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
