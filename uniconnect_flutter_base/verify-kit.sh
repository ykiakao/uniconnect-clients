#!/usr/bin/env bash
set -euo pipefail

fail() { echo "[FAIL] $1"; exit 1; }
pass() { echo "[OK] $1"; }

[ -f AGENTS.md ] || fail "AGENTS.md ausente"
[ -f bootstrap-project.sh ] || fail "bootstrap-project.sh ausente"
[ -d .codex-kit ] || fail ".codex-kit/ ausente"
[ -d .codex-kit/skills ] || fail ".codex-kit/skills/ ausente"
[ -d .codex-kit/agents ] || fail ".codex-kit/agents/ ausente"
[ -d .codex-kit/templates ] || fail ".codex-kit/templates/ ausente"
[ -f .codex-kit/agents/code-reviewer.md ] || fail ".codex-kit/agents/code-reviewer.md ausente"
[ ! -e agents ] || fail "agents/ não deve existir na raiz"
[ ! -e skills ] || fail "skills/ não deve existir na raiz"
[ ! -e templates ] || fail "templates/ não deve existir na raiz"

bash -n bootstrap-project.sh || fail "bootstrap-project.sh com erro de sintaxe"
pass "Estrutura do kit validada: AGENTS.md na raiz e restante em .codex-kit/"
