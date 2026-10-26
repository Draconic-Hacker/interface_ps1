# interface_ps1

Menu de inventário de máquinas (notebooks e desktops Windows) feito em PowerShell. Em poucos segundos mostra hardware, sistema, usuários, aplicativos e o código do AnyDesk, e gera um relatório em `.txt` — sem instalar nada e sem enviar dados para fora da máquina.

## O que ele coleta

| Opção | Informações |
|---|---|
| **[1] Resumo geral** | Marca, modelo, **MTM**, **MO**, número de série, CPU, GPU, RAM total e discos |
| **[2] Sistema operacional** | Edição, versão, build, arquitetura, data de instalação, último boot e uptime, nome da máquina, domínio, usuário atual |
| **[3] BIOS / Placa-mãe / TPM** | Versão e data da BIOS, placa-mãe, Secure Boot, TPM |
| **[4] Memória RAM** | Por slot: tipo (DDR3/DDR4/DDR5), capacidade, velocidade, fabricante, part number e S/N |
| **[5] Discos e volumes** | Discos físicos (tipo, modelo, tamanho) e volumes (total, livre e % livre) |
| **[6] Rede** | Adaptadores ativos: IP, MAC, máscara, gateway, DNS e DHCP |
| **[7] Usuários da máquina** | Usuários locais, se estão ativos, tipo (**Administrador** ou **Comum**) e último logon |
| **[8] Aplicativos instalados** | Lista paginada, com busca por nome e colunas opcionais (fabricante, data de instalação, origem) |
| **[9] AnyDesk** | Código de acesso (instalação padrão e versão portable) |
| **[10] TUDO na tela** | Todas as seções acima, em sequência |
| **[11] Baixar relatório** | Exporta para `.txt` ou `.csv` (veja [Relatórios](#relatórios)) |

## Requisitos

- Windows 10 ou 11 com **Windows PowerShell 5.1** (já vem no Windows). É a versão em que o script foi testado.
- Internet apenas para baixar o script do GitHub.
- **Executar como administrador é recomendado.** Sem isso, itens como TPM, Secure Boot e alguns dados de BIOS e discos podem aparecer como `N/D`. O topo do menu mostra o contexto atual (`ADMIN` ou `USUARIO COMUM`).

## Como usar

### Opção 1: arquivo `.bat` (recomendado)

Use o `Info-System-lock.bat` deste repositório. Dê dois cliques, ou clique com o botão direito e escolha **Executar como administrador**. Ele baixa e executa a versão do script que estiver fixada no arquivo:

```bat
@echo off
set "COMMIT=<hash-do-commit>"

start powershell -noexit -command "Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/%COMMIT%/info-sistema.ps1' -UseBasicParsing).Content"
```

O `COMMIT` é o hash da versão. Para saber qual hash corresponde a qual versão, consulte o [CHANGELOG](CHANGELOG.md).

### Opção 2: direto no PowerShell

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/<COMMIT>/info-sistema.ps1'))
```

Troque `<COMMIT>` pelo hash da versão desejada.

### Opção 3: arquivo local

```powershell
powershell -ExecutionPolicy Bypass -File .\info-sistema.ps1
```

> O script é executado direto da memória nas opções 1 e 2, sem salvar um arquivo `.ps1`. Por isso a política de execução de scripts do Windows não se aplica a elas.

## Menu

```
  +--------------------------------------------------------+
  |            INVENTARIO DE MAQUINA - NOME-DA-MAQUINA     |
  +--------------------------------------------------------+
   Versao:   vX.Y.Z
   Contexto: ADMIN

   [1] Resumo geral (marca, modelo, S/N, CPU, GPU, RAM, discos)
   [2] Sistema operacional
   [3] BIOS / Placa-mae / TPM
   [4] Memoria RAM (por slot)
   [5] Discos fisicos e volumes
   [6] Rede (IP, MAC, gateway, DNS)
   [7] Usuarios da maquina (local / administrador)
   [8] Aplicativos instalados (lista paginada)
   [9] AnyDesk (codigo de acesso)
   [10] TUDO na tela
   [11] Baixar relatorio (Area de Trabalho ou local a escolher)

   [0] Sair
```

O texto do menu não tem acentos de propósito: o script é baixado pela internet e a codificação de caracteres poderia corromper o texto em algumas máquinas.

## Relatórios

A opção **[11] Baixar relatório** abre um submenu:

| Opção | O que faz |
|---|---|
| **[1] Inventário completo → Área de Trabalho** | Salva direto na Área de Trabalho |
| **[2] Inventário completo → selecionar local** | Abre a janela do Windows para você escolher a pasta |
| **[3] Inventário personalizado** | Você escolhe o que entra no relatório e depois onde salvar |

Depois de escolher uma delas, o script pergunta o **formato** do relatório:

| Formato | Para que serve |
|---|---|
| **[1] .txt** (padrão, basta apertar ENTER) | Relatório em texto, para ler |
| **[2] .csv** | Planilha em formato longo, para abrir no Excel e juntar vários computadores (veja [CSV](#csv-formato-longo)) |
| **[3] .json** | Em breve |

Use `0` para cancelar e voltar ao submenu.

Nomes dos arquivos gerados (a extensão depende do formato escolhido):

- `Inventario_<MAQUINA>_<AAAA-MM-DD_HHMM>.txt` ou `.csv` (completo)
- `Inventario_Personalizado_<MAQUINA>_<AAAA-MM-DD_HHMM>.txt` ou `.csv` (personalizado)

### Inventário personalizado

Uma tela de seleção mostra todas as seções, e você marca o que quer no relatório:

- Em **Resumo, Sistema operacional, BIOS/TPM e AnyDesk** você marca **campo a campo** (digite o número da seção para abrir a lista de campos).
- Em **Memória, Volumes, Rede, Usuários e Aplicativos** você marca o **bloco inteiro**.
- Atalhos: `A` marca tudo, `L` limpa, `B` seleciona só a identificação da máquina (marca, modelo, MTM, MO, S/N e AnyDesk) e `G` gera o relatório.

### CSV (formato longo)

Um arquivo só, com uma linha para cada informação, separado por `;` e em UTF-8 (abre direto no Excel em português). Colunas:

| Coluna | Conteúdo |
|---|---|
| `Maquina` | Nome da máquina |
| `DataColeta` | Data e hora da coleta |
| `Secao` | Seção do inventário (Resumo, Memória RAM, Usuários, Aplicativos...) |
| `Item` | Identifica a linha nas seções de tabela (slot, usuário, nome do aplicativo...). Fica vazio nos campos soltos |
| `Campo` | Nome da informação |
| `Valor` | Valor da informação |

Exemplo:

```
"Maquina";"DataColeta";"Secao";"Item";"Campo";"Valor"
"PC-EXEMPLO";"2026-10-25 20:10:03";"Resumo";"";"Marca";"Dell Inc."
"PC-EXEMPLO";"2026-10-25 20:10:03";"Memoria RAM (por slot)";"DIMM A";"Tipo";"DDR4"
"PC-EXEMPLO";"2026-10-25 20:10:03";"Aplicativos instalados";"7-Zip 26.02 (x64)";"Versao";"26.02"
```

- Há também uma linha `Relatorio` / `Versao do script`, que informa qual versão do script gerou o arquivo.
- Para juntar vários computadores, basta somar as linhas dos arquivos, porque o cabeçalho é o mesmo.
- No inventário personalizado, o CSV traz só o que você marcou.
- Valores que começam com `=`, `+`, `-` ou `@` recebem um apóstrofo na frente, para o Excel não tratá-los como fórmula.

## Detalhes de cada informação

### Aplicativos instalados

A coluna **Origem** indica de onde veio cada aplicativo:

- **Win32 (64-bit) / Win32 (32-bit) / Usuario atual**: programas tradicionais, instalados por `.exe` ou `.msi`, lidos do Registro do Windows. "Win32" é o nome da API clássica do Windows, não indica 32 bits. O "(64-bit)" e "(32-bit)" dizem só em qual parte do Registro o programa foi registrado. "Usuario atual" são programas instalados apenas para o usuário que está executando o script.
- **Store (UWP)**: aplicativos modernos (formato MSIX/APPX). O nome vem do formato do pacote, não de onde você baixou. A lista inclui os aplicativos que já vêm com o Windows (Calculadora, Fotos, Xbox etc.) e os instalados fora da Store por política da empresa ou pelo winget. Bibliotecas internas e componentes do sistema são filtrados.

O rodapé mostra o total, quantos são tradicionais e quantos são modernos. Aplicativos portable, que não têm instalador, não aparecem.

### Usuários e tipo (Administrador ou Comum)

- Os usuários vêm das contas locais da máquina.
- O tipo é definido pela participação no grupo **Administradores** local. O grupo é localizado pelo identificador `S-1-5-32-544`, então funciona em qualquer idioma do Windows.
- Contas de domínio ou Azure AD que também são administradoras da máquina aparecem com **Origem = Dominio / Azure AD**.
- Usuários de domínio sem privilégio de administrador não aparecem nessa lista, porque não têm conta local.

### AnyDesk

O código (`ad.anynet.id`) é lido de dois lugares:

- **Instalado**: `%ProgramData%\AnyDesk\system.conf`
- **Portable**: `%APPDATA%\AnyDesk\system.conf` (perfil de quem executa o script)

Se o arquivo não existir ou não tiver o código, aparece `Nao encontrado`.

### MTM e MO

São lidos dos dados que o fabricante grava na BIOS. O conteúdo varia por marca e por geração do equipamento, e em placas genéricas pode aparecer `N/D`. Confira os valores com a etiqueta da máquina.

### Tipo de memória

Vem do campo SMBIOS da memória: `24` = DDR3, `26` = DDR4, `34` = DDR5. Outros códigos aparecem como `Desconhecido (codigo N)`.

## Versionamento

Cada versão do script corresponde a um **commit**, e o `.bat` aponta para o hash desse commit. Assim, quem usa o `.bat` continua na mesma versão até ele ser atualizado, e uma alteração na branch não passa a rodar nas máquinas sem aprovação.

A versão do script aparece no cabeçalho do menu (`Versao: vX.Y.Z`) e dentro dos relatórios gerados.

Para publicar uma nova versão:

1. Faça o commit do script e anote o hash do commit que alterou o `info-sistema.ps1`: `git log -1 --format=%H -- info-sistema.ps1`.
2. Registre a versão no [CHANGELOG](CHANGELOG.md), com esse hash.
3. Troque o valor de `COMMIT` no `.bat` e faça um commit separado.
4. Crie a tag da versão nesse mesmo commit do script: `git tag -a vX.Y.Z <hash> -m ":bookmark: Versao X.Y.Z"`.

Os commits seguem o [padrão de commits do iuricode](https://github.com/iuricode/padroes-de-commits), por exemplo `:sparkles: feat: ...`, `:bug: fix: ...` e `:books: docs: ...`.

## Segurança e privacidade

- O script **só lê** informações da máquina. Ele **não envia dados para a internet**; o único acesso à rede é o download do próprio script.
- Ele só grava um arquivo quando você escolhe exportar um relatório, na pasta que você definir.
- Os relatórios contêm dados sensíveis (números de série, usuários, aplicativos e o código de acesso do AnyDesk). Guarde-os em local com acesso restrito.
- O código é aberto. Revise-o antes de executar em um ambiente que não seja o seu.

## Limitações conhecidas

- A lista de aplicativos do Registro (usuário atual) e da Store considera apenas o usuário que executa o script. Se você executar como outro administrador, os aplicativos instalados só para o usuário da máquina não aparecem.
- O AnyDesk portable é lido só do perfil de quem executa o script.
- Testado no Windows PowerShell 5.1.

## Estrutura do repositório

```
interface_ps1/
├── info-sistema.ps1        # o script
├── Info-System-lock.bat    # executa uma versão fixa (por hash) do script
├── README.md
└── CHANGELOG.md
```

## Ideias para o futuro

- Exportar em JSON e em outros formatos de CSV: uma linha por máquina (para consolidar vários computadores) e um arquivo por seção.
- Salvar perfis de seleção do inventário personalizado.
- Coletar de várias máquinas ao mesmo tempo, de forma online.
- Listar perfis de usuário de domínio (pasta `C:\Users`).