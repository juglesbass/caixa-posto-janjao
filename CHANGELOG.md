# Changelog

Todas as mudanças notáveis neste projeto estão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e este projeto segue [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-07-11

### Added
- ✨ Sistema de logging estruturado com arquivo de auditoria em `backups/logs/`
- 📝 Arquivo de configuração centralizado (`config.py`)
- 🧪 Testes unitários para módulo de banco de dados
- 🔄 CI/CD workflow com GitHub Actions
- 📚 Documentação de desenvolvimento (CONTRIBUTING.md)
- 🎨 Módulo de UI separado com paleta de cores (`ui/paleta.py`)

### Changed
- 🔐 Melhorado `.gitignore` com mais padrões de exclusão
- 📦 Atualizado `pyproject.toml` com dependências de desenvolvimento
- 🚀 Estrutura do projeto refatorada para modularidade

### Fixed
- 🐛 Removido arquivos de banco de dados (`*.db-shm`, `*.db-wal`) do repositório

## [0.2.0] - 2026-07-01

### Added
- Suporte para múltiplas formas de pagamento (cartões, PIX, etc)
- Backup automático em CSV
- Interface responsiva para mobile e desktop
- Proteção por PIN
- Tema claro/escuro

### Fixed
- Melhorias gerais de estabilidade

## [0.1.0] - Início

### Added
- Funcionalidade básica de caixa
- Banco de dados SQLite
- Interface com Flet
