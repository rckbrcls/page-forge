# Scout Report

## Entry points

- `legacy/python-tui-cli/src/page_forge/cli.py` — CLI Typer commands: `readiness` and `readiness-folder`
- `legacy/python-tui-cli/src/page_forge/tui_app.py` — TUI views: "Run Doctor" (`run-readiness`) and "Prepare for Kindle" (`prepare-readiness`)
- `PageForge/Domain/Models/DomainEnums.swift` — Swift operation kinds: `.readinessAudit`, `.readinessPrepare`, `.batchReadiness`
- `PageForge/Domain/Models/ReadinessModels.swift` — Swift interface contracts for readiness jobs and models

## Key symbols

- `audit_book(source)` in `legacy/python-tui-cli/src/page_forge/readiness.py` — Runs inspection and builds `ReadinessReport`
- `prepare_book_for_kindle(source)` in `legacy/python-tui-cli/src/page_forge/readiness.py` — Orchestrates conversion (if MOBI), structural repair, and re-audit
- `EPUBInspection` in `PageForge/Domain/Services/EPUBInspection.swift` — Swift-native ZIP archive reading and OPF container metadata checks

## Relationships

- O fluxo de prontidão (readiness flow) no CLI/TUI consome `readiness.py`.
- Se o arquivo for `.mobi`, ele primeiro passa por `conversion.py:convert_book` para gerar um `.epub` temporário antes de ser auditado.
- Se o usuário solicitar correções (`fix=True`), o arquivo é consertado através de `conversion.py:repair_epub` (usando `mode="safe"`), que chama `epub_repair.py:repair_epub_structure` e `ebook-polish`.
- O relatório resultante é enviado para entrega via SMTP por `kindle.py:send_to_kindle` ou direcionado ao site da Amazon via handoff URL.

## Likely change surface

- `PageForge/Domain/Services/` — Necessidade de portar a lógica do `ReadinessDoctor` e `EPUBRepair` (safe mode) para Swift.
- `PageForge/Features/Readiness/` — Implementação das views SwiftUI de auditoria de prontidão.

## Uncertainties

- A compressão ZIP inflada via framework `Compression` nativo do macOS (`EPUBInspection.swift`) precisa ser robusta o suficiente para lidar com EPUBs reais de múltiplos pacotes, similar ao `zipfile` do Python.

---

## Handoff: Readiness Flow

### Entry points

- **Python (Legacy):**
  - **CLI:** `page-forge readiness <file>` e `page-forge readiness-folder <folder>` em `src/page_forge/cli.py`.
  - **TUI:** Aba "Readiness" em `src/page_forge/tui_app.py`, disparada pelos botões `Run Doctor` e `Prepare for Kindle`.
- **Swift (macOS):**
  - Modelado sob os enums de `Domain/Models/DomainEnums.swift` com `OperationKind.readinessAudit` e `.readinessPrepare`.

### Core files

- `legacy/python-tui-cli/src/page_forge/readiness.py` — Lógica orquestradora central (auditorias, heurísticas do Kindle e preparação).
- `legacy/python-tui-cli/src/page_forge/epub_repair.py` — Correções estruturais seguras.
- `PageForge/Domain/Models/ReadinessModels.swift` — Modelos de dados em Swift (`ReadinessIssue`, `ReadinessReport`).
- `PageForge/Domain/Services/EPUBInspection.swift` — Leitor ZIP nativo e parsing de OPF estrutural.

### Flow (ordered)

1. **Audit (Auditar):**
   - Verifica tipo de arquivo: se `.mobi`, reporta `mobi_conversion_needed`; se não for `.epub` ou `.mobi`, bloqueia.
   - Extrai/Valida integridade do ZIP (caminhos inseguros, ZIP corrompido, arquivo `mimetype` ausente/comprimido/incorreto).
   - Valida arquivo XML de container (`META-INF/container.xml`) e arquivo de pacote OPF.
   - Analisa XML do OPF: presença de `<manifest>`, `<spine>`, referências corretas de `href` nos itens e integridade do `spine`.
   - Heurísticas do Kindle: valida limite de tamanho total do arquivo (< 200MB), número de arquivos HTML (< 300), tamanho de arquivos HTML individuais (< 30MB) e arquivos de fonte vazios.
   - Verifica metadados básicos (título e autor) e imagem de capa.
2. **Fix (Corrigir):**
   - Se o arquivo for `.mobi`, faz a conversão prévia com `ebook-convert` para obter um EPUB temporário.
   - Executa `repair_epub` com `mode="safe"`.
   - Gera a estrutura limpa gravando o arquivo mimetype correto sem compressão como primeiro registro do ZIP.
   - Normaliza caminhos de arquivo no OPF e valida os tipos de mídia.
   - Executa `ebook-polish --upgrade-book` no EPUB gerado para refinar a estrutura final.
3. **Status (Atualizar Status):**
   - Roda auditoria novamente no EPUB limpo para verificar se restou algum problema.
4. **Send / Handoff (Enviar / Redirecionar):**
   - Se o status for `ready`, o usuário pode:
     - Enviar via SMTP (utilizando configurações de perfil SMTP).
     - Abrir a URL de handoff oficial do Amazon Send to Kindle (`https://www.amazon.com/sendtokindle`).

### Contracts & vocabulary

- **Vocabulary de Status:**
  - `ready` — Sem problemas impeditivos de severidade `error` ou `fixable`.
  - `needs_fixes` — Contém apenas problemas severidade `fixable`.
  - `blocked` — Contém pelo menos um problema de severidade `error`.
- **Vocabulary de Severidade (Severity):**
  - `error` — Erros fatais na estrutura que inviabilizam a conversão ou validação automática.
  - `fixable` — Erros de conformidade que o reparador seguro consegue resolver (ex: mimetype incorreto, referências de tipo de mídia incompatíveis).
  - `warning` — Recomendações e avisos das heurísticas da Amazon (ex: metadados ausentes, capa não declarada, arquivo excessivamente grande).
  - `info` — Mensagens informativas.
- **Output Contracts:**
  - `*-kindle-ready.epub` — Nome padrão do arquivo tratado pelo fluxo Readiness Doctor (preparado com `mode="safe"` e reauditado).
  - `*-repaired.epub` — Nome de arquivo reservado apenas para fluxos de reparo manuais sem o Readiness Doctor completo.

### Boundaries

- **Readiness:** Responsável estritamente pela validação estrutural do EPUB, regras e heurísticas de conformidade do Kindle e verificação se o estado do arquivo é elegível para o Send to Kindle.
- **EPUB Repair:** Responsável pela reescrita física do arquivo ZIP, garantindo mimetype correto e ordenado, consertando manifestos OPF, namespaces e referências internas.
- **Conversion:** Interface com o executável `ebook-convert` da Calibre para transformações de formato (ex: MOBI -> EPUB).
- **Send:** Responsável pelo encapsulamento do transporte via SMTP do arquivo gerado para o e-mail @kindle.com.

### Key symbols

- `audit_book` (`legacy/python-tui-cli/src/page_forge/readiness.py`) — Função principal de diagnóstico.
- `prepare_book_for_kindle` (`legacy/python-tui-cli/src/page_forge/readiness.py`) — Função principal de orquestração do reparo e geração do novo arquivo prontificado.
- `EPUBInspection` (`PageForge/Domain/Services/EPUBInspection.swift`) — Ponto de partida do parse em Swift para leitura do arquivo EPUB/ZIP.

### Open risks / unknowns

- A lógica de reparo estrutural de EPUB (`epub_repair.py`) reescreve arquivos binários ZIP manipulando individualmente cada entrada. Portar isso para Swift exigirá testes minuciosos no tratamento do Compression framework e manipulação de arquivos ZIP diretamente em memória para evitar corrupção dos metadados.
