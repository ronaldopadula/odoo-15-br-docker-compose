#!/usr/bin/env python3
"""
Gera o README de cada versão do Odoo a partir de um único modelo.

    python3 docs/gerar_readmes.py            # gera README.md (Odoo 15) e docs/readmes/README-<versão>.md
    python3 docs/gerar_readmes.py --verificar # falha se algum README estiver desatualizado

O README.md deste repositório é o da versão 15. Os demais vão para docs/readmes/
e devem ser copiados para o repositório da respectiva versão
(ronaldopadula/odoo-<versão>-br-docker-compose).
"""
import pathlib
import sys

DONO = "ronaldopadula"
CENTRAL = "odoo-15-br-docker-compose"
RAW = f"https://raw.githubusercontent.com/{DONO}"
IMG = f"{RAW}/{CENTRAL}/master/screenshots"

# Situação de cada versão (datas conferidas no repositório oficial github.com/odoo/docker).
VERSOES = {
    14: dict(suporte=False, imagem_retirada="10/11/2023"),
    15: dict(suporte=False, imagem_retirada="07/10/2024"),
    16: dict(suporte=False, imagem_retirada="18/09/2025"),
    17: dict(suporte=False, imagem_retirada="24/09/2026"),
    18: dict(suporte=True),
    19: dict(suporte=True),
}
# Ramo principal de cada repositório (os criados em 2026 usam "main").
RAMO = {14: "master", 15: "master", 16: "master", 17: "main", 18: "main", 19: "main"}

# Repositórios cuja versão antiga publicava uma senha mestra fixa.
LEGADO_SENHA_PUBLICA = {14, 15, 16}


def repo(v):
    return f"odoo-{v}-br-docker-compose"


def aviso(v):
    info = VERSOES[v]
    if info["suporte"]:
        return (f"> O Odoo {v} tem imagem oficial mantida pela Odoo. Para uso real, siga o passo\n"
                f"> **\"Usar com domínio (HTTPS)\"** mais abaixo.")
    return (f"> O Odoo {v} já não tem imagem oficial mantida pela Odoo (retirada em {info['imagem_retirada']}).\n"
            f"> Use-o para manter bases que já estão nessa versão. Para uso real, siga o passo\n"
            f"> **\"Usar com domínio (HTTPS)\"** mais abaixo.")


def tabela_versoes(atual):
    linhas = ["| Versão | Situação | Repositório |", "|---|---|---|"]
    for v in sorted(VERSOES, reverse=True):
        situacao = "com suporte da Odoo" if VERSOES[v]["suporte"] else "sem suporte (bases existentes)"
        nome = f"**Odoo {v}** (este)" if v == atual else f"Odoo {v}"
        linhas.append(f"| {nome} | {situacao} | [{repo(v)}](https://github.com/{DONO}/{repo(v)}) |")
    return "\n".join(linhas)


def legado(v):
    if v == 15:
        return """<details>
<summary>Instalações feitas com versões anteriores deste repositório</summary>

- **Versão original:** a senha mestra era fixa e pública (continua visível no histórico do Git).
  Troque `admin_passwd` em `etc/odoo.conf` e não deixe as portas do Odoo abertas diretamente.
- **Versões com Nginx (outubro/2026):** continuam funcionando. Para migrar, faça backup das bases,
  instale com esta versão e restaure.

</details>
"""
    if v in LEGADO_SENHA_PUBLICA:
        return """<details>
<summary>Instalações feitas com a versão antiga deste repositório</summary>

A versão antiga usava uma **senha mestra fixa e pública** (continua visível no histórico do Git) e
deixava a porta do Odoo aberta para a internet. Em toda instalação feita com ela:

1. **Troque a senha mestra:** edite `admin_passwd` em `etc/odoo.conf` e reinicie (`sudo docker-compose restart`).
2. De preferência, **migre**: faça backup das bases pelo Gerenciador de Bancos, instale com o comando
   acima e restaure as bases na instalação nova.

</details>
"""
    return ""


def gerar(v):
    pasta = f"odoo{v}"
    porta = 10000 + v
    eh_central = v == 15
    instalar_url = f"{RAW}/{repo(v)}/{RAMO[v]}/instalar.sh"
    img = "screenshots" if eh_central else IMG

    origem = (
        "Este repositório contém o instalador. Os repositórios das outras versões chamam este mesmo\n"
        "instalador, só mudando a versão — assim, uma correção vale para todas."
        if eh_central else
        f"O `instalar.sh` deste repositório é um atalho: ele baixa o instalador mantido em\n"
        f"[{CENTRAL}](https://github.com/{DONO}/{CENTRAL}) e o executa sempre com o **Odoo {v}**.\n"
        f"Assim, uma correção de segurança feita lá vale para todas as versões."
    )
    opcao_versao = (
        "| `VERSAO=14` a `19` | instalar outra versão do Odoo (padrão: 15) |\n" if eh_central else ""
    )

    return f"""# Em primeiro lugar:
Fork criado apenas para utilização em demonstração. Tradução ao Português com todos os créditos ao criador do código.

# Odoo {v} em um comando

Instala o **Odoo {v}** num servidor Linux (Ubuntu ou Debian) com **um único comando**.
Ao final, o instalador mostra o endereço de acesso e todas as senhas.

{aviso(v)}

Precisa de outra versão? Cada uma tem o seu repositório:

{tabela_versoes(v)}

Uma base só abre na mesma versão em que foi criada. Se você já usa o Odoo, instale a versão das suas bases.

---

## Instalação passo a passo

### 1. Entre no servidor

Pelo console do provedor (ex.: DigitalOcean › *Droplet* › *Console*) ou por SSH:

``` bash
ssh root@IP_DO_SERVIDOR
```

### 2. Rode o instalador

``` bash
curl -fsSLO {instalar_url}
sudo bash instalar.sh {pasta} {porta}
```

- `{pasta}` é o nome da pasta onde a instalação fica guardada.
- `{porta}` é a porta de acesso.

O instalador faz tudo sozinho: instala o Docker (se precisar), gera as senhas e liga o Odoo.
Leva de 3 a 10 minutos.

### 3. Guarde os dados do quadro final

No final aparece um quadro com os endereços e as senhas:

```
==============================================================
 Odoo {v} pronto

   Acesse:                http://IP_DO_SERVIDOR:{porta}
   Gerenciador de Bancos: http://IP_DO_SERVIDOR:{porta}/web/database/manager
     usuário do proxy:    gestor
     senha do proxy:      ••••••••
     senha mestra:        ••••••••
==============================================================
```

### 4. Crie a sua primeira base de dados

Abra o endereço do **Gerenciador de Bancos**. O navegador pede um usuário e uma senha:
digite **`gestor`** e a **senha do proxy** mostrada no quadro.

> **Não abriu?** O provedor provavelmente tem um firewall. Na DigitalOcean:
> *Networking › Firewalls* › regra de entrada liberando a porta **{porta}** (TCP).

<img src="{img}/1-senha-do-gerenciador.png" width="600" alt="Janela de usuário e senha do navegador">

> O aviso "conexão não é particular" aparece porque o acesso pelo IP não tem criptografia.
> Ele some quando você usa um domínio (veja *Usar com domínio (HTTPS)*).

Em seguida aparece o formulário de criação da base. Ele é do próprio Odoo e vem em inglês
(as imagens são do Odoo 15; nas outras versões a aparência muda um pouco, mas os campos são os mesmos):

<img src="{img}/2-criar-base.png" width="380" alt="Formulário de criação de base do Odoo">

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

<img src="{img}/4-escolher-base.png" width="380" alt="Tela de escolha da base de dados">

Entre com o e-mail e a senha que você definiu no formulário:

<img src="{img}/5-login.png" width="260" alt="Tela de login do Odoo em português">

Pronto. A tela inicial mostra os aplicativos que você pode instalar (Vendas, Compras, Estoque,
Contabilidade etc.):

<img src="{img}/6-aplicativos.png" width="700" alt="Tela de aplicativos do Odoo em português">

> Os botões **Upgrade** são de recursos da versão paga (Enterprise), que não fazem parte desta
> instalação. Use os aplicativos com o botão **Instalar**.

---

## Perguntas frequentes

### Perdi as senhas. Como vejo de novo?

``` bash
sudo cat {pasta}/.credenciais
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

Sim, inclusive de versões diferentes (veja a tabela no início). Cada um com sua pasta e sua porta:

``` bash
sudo bash instalar.sh {pasta}-b {porta + 1000}
```

### Usar com domínio (HTTPS) — recomendado para uso real

1. No seu provedor de domínio, crie um registro **tipo A** apontando, por exemplo,
   `erp.seudominio.com.br` para o IP do servidor.
2. No firewall do provedor de nuvem, libere as portas **80** e **443**.
3. Instale assim:

``` bash
sudo DOMINIO=erp.seudominio.com.br bash instalar.sh {pasta}-prod {porta}
```

O endereço passa a ser `https://erp.seudominio.com.br`, com certificado gratuito, emitido e
renovado automaticamente. Só uma instalação por servidor pode usar domínio.

### Quero já criar uma base na instalação

Acrescente o nome da base no final do comando:

``` bash
sudo bash instalar.sh {pasta} {porta} minhaempresa
```

O quadro final mostra o usuário `admin` e a senha dessa base.

### Como faço backup?

Pelo navegador, no **Gerenciador de Bancos**:

<img src="{img}/3-gerenciador.png" width="380" alt="Gerenciador de Bancos com as opções Backup, Duplicate e Delete">

| Botão | Para quê |
|---|---|
| **Backup** | baixa uma cópia da base (escolha o formato *zip*: inclui os anexos) |
| **Duplicate** | cria uma cópia da base no servidor (útil para testes) |
| **Delete** | exclui a base — **não tem volta** |
| **Restore Database** | carrega um backup baixado antes |
| **Set Master Password** | troca a senha mestra |

Todas as operações pedem a senha mestra.

### Como ligo, desligo ou reinicio?

Dentro da pasta da instalação (`cd {pasta}`):

| Ação | Comando |
|---|---|
| Ligar | `sudo docker compose up -d` |
| Desligar | `sudo docker compose down` |
| Reiniciar | `sudo docker compose restart` |
| Ver o que está acontecendo (log) | `sudo docker compose logs -f odoo` |

O Odoo volta a ligar sozinho se o servidor reiniciar.

### Como instalo módulos extras (addons)?

Copie as pastas dos módulos para `{pasta}/addons/`, rode `sudo docker compose restart` e,
no Odoo, vá em *Aplicativos › Atualizar lista de aplicativos*. Os módulos precisam ser da
versão {v}.

---

## Detalhes técnicos

{origem}

<details>
<summary>Como a instalação é montada</summary>

```
navegador ──> proxy Caddy (porta da instância) ──> Odoo {v} ──> PostgreSQL
```

- Só o proxy recebe conexões de fora. Odoo e PostgreSQL ficam numa rede interna do Docker, sem portas publicadas.
- O proxy encaminha o live chat e protege com `basic_auth` as rotas do Gerenciador de Bancos e do
  serviço de bancos da API (`/xmlrpc/db`, `/xmlrpc/2/db`, `/jsonrpc`).
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
{opcao_versao}| `DOMINIO=erp.exemplo.com.br` | publica com HTTPS automático |
| `EMAIL=ti@exemplo.com.br` | contato para avisos do certificado (opcional) |
| `POSTGRES_IMAGE=postgres:14` | fixar outra versão do PostgreSQL (padrão: automática) |

</details>

<details>
<summary>Backup e restauração pelo console (bases grandes)</summary>

``` bash
cd {pasta}
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

{legado(v)}"""


def main():
    raiz = pathlib.Path(__file__).resolve().parent.parent
    saida = raiz / "docs" / "readmes"
    saida.mkdir(parents=True, exist_ok=True)
    verificar = "--verificar" in sys.argv
    alvos = {v: (raiz / "README.md" if v == 15 else saida / f"README-{v}.md") for v in VERSOES}
    desatualizados = []
    for v, caminho in alvos.items():
        texto = gerar(v).rstrip() + "\n"
        if verificar:
            if not caminho.exists() or caminho.read_text() != texto:
                desatualizados.append(str(caminho.relative_to(raiz)))
        else:
            caminho.write_text(texto)
            print(f"gerado: {caminho.relative_to(raiz)}")
    if verificar and desatualizados:
        print("desatualizados:", ", ".join(desatualizados))
        sys.exit(1)


if __name__ == "__main__":
    main()
