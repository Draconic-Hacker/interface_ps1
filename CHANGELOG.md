# Changelog

Todas as mudanças relevantes deste projeto são registradas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o versionamento segue o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

Cada versão tem o **hash do commit** correspondente. É esse hash que vai na variável `COMMIT` do `Info-System-lock.bat` para fixar a versão.

## [1.0.0] - 2026-10-23

Commit: `8c7b257f266e1e8895db6a4dbaed83c9cda9da6e`

### Adicionado
- **Usuários da máquina** (opção 7): usuários locais com tipo (Administrador ou Comum), situação (ativo) e último logon. Contas de domínio ou Azure AD que são administradoras aparecem à parte. O grupo de administradores é localizado pelo identificador do grupo, então funciona em qualquer idioma do Windows.
- **Aplicativos instalados** (opção 8): lista do Registro (64-bit, 32-bit e usuário atual) mais aplicativos da Store, sem duplicados, componentes ocultos e atualizações.
- **Paginação dos aplicativos**: navegação por páginas, ir para uma página, busca por nome, escolha de itens por página e colunas opcionais (fabricante, instalado em, origem).
- **AnyDesk** (opção 9): código de acesso da instalação padrão e da versão portable.
- O **relatório completo** passa a incluir AnyDesk, usuários e aplicativos.
- O **inventário personalizado** passa a ter as seções de AnyDesk, usuários e aplicativos, com rodapé de totais e atalho de identificação (`B`) incluindo o AnyDesk.

### Alterado
- Numeração do menu principal: `[7]` Usuários, `[8]` Aplicativos, `[9]` AnyDesk, `[10]` TUDO na tela e `[11]` Baixar relatório.
- Rodapé dos aplicativos: "Total | Tradicionais (Win32) | Apps modernos (Store/Windows)".

## [0.3.0]

Commit: `9446b55`

### Adicionado
- **Inventário personalizado** no submenu de relatório: seleção de seções e campos, atalhos de marcar e limpar tudo, e escolha do destino do arquivo.

## [0.2.0]

Commit: `7c8b8ef`

### Adicionado
- Campos **MTM** e **MO** no resumo geral.
- **Tipo da memória RAM** (DDR3, DDR4 e DDR5) na listagem por slot.
- Submenu **Baixar relatório**: exportar para a Área de Trabalho ou escolher a pasta em uma janela de seleção.
- A opção de sair fecha o programa.

## [0.1.1]

Commit: `0d69b02`

### Corrigido
- Compatibilidade com o Windows PowerShell 5.1 nas informações de BIOS (Secure Boot e TPM) e de volumes (% livre). O script falhava ao ser analisado antes de executar.

## [0.1.0]

Commit: `331dd1d`

### Adicionado
- Primeira versão: menu com resumo geral, sistema operacional, BIOS/placa-mãe/TPM, memória RAM, discos e volumes, rede, tudo na tela e exportação do relatório para a Área de Trabalho.

[1.0.0]: https://github.com/Draconic-Hacker/interface_ps1/commit/8c7b257f266e1e8895db6a4dbaed83c9cda9da6e
[0.3.0]: https://github.com/Draconic-Hacker/interface_ps1/commit/9446b55
[0.2.0]: https://github.com/Draconic-Hacker/interface_ps1/commit/7c8b8ef
[0.1.1]: https://github.com/Draconic-Hacker/interface_ps1/commit/0d69b02
[0.1.0]: https://github.com/Draconic-Hacker/interface_ps1/commit/331dd1d
