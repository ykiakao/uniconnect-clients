#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Uso: ./bootstrap-project.sh <KIT_PATH> <PROJECT_PATH>"
  exit 1
fi

KIT_PATH="$1"
PROJECT_PATH="$2"

mkdir -p "$PROJECT_PATH/.codex-kit"

# AGENTS na raiz do projeto consumidor
if [ -f "$KIT_PATH/AGENTS.md" ]; then
  cp "$KIT_PATH/AGENTS.md" "$PROJECT_PATH/AGENTS.md"
else
  echo "Erro: AGENTS.md não encontrado em $KIT_PATH"
  exit 1
fi

# Resolve origem de cada bloco (aceita layout novo, legado e híbrido)
resolve_src_dir() {
  local name="$1"

  if [ -d "$KIT_PATH/.codex-kit/$name" ]; then
    echo "$KIT_PATH/.codex-kit/$name"
    return 0
  fi

  if [ -d "$KIT_PATH/$name" ]; then
    echo "$KIT_PATH/$name"
    return 0
  fi

  return 1
}

AGENTS_SRC="$(resolve_src_dir agents || true)"
SKILLS_SRC="$(resolve_src_dir skills || true)"
TEMPLATES_SRC="$(resolve_src_dir templates || true)"

if [ -z "${AGENTS_SRC:-}" ] || [ -z "${SKILLS_SRC:-}" ] || [ -z "${TEMPLATES_SRC:-}" ]; then
  echo "Erro: estrutura inválida em $KIT_PATH"
  echo "Encontrado:"
  [ -n "${AGENTS_SRC:-}" ] && echo "  agents: $AGENTS_SRC" || echo "  agents: MISSING"
  [ -n "${SKILLS_SRC:-}" ] && echo "  skills: $SKILLS_SRC" || echo "  skills: MISSING"
  [ -n "${TEMPLATES_SRC:-}" ] && echo "  templates: $TEMPLATES_SRC" || echo "  templates: MISSING"
  echo
  echo "Esperado em um destes formatos:"
  echo "  - .codex-kit/{agents,skills,templates}"
  echo "  - {agents,skills,templates} na raiz"
  echo "  - ou híbrido contendo os três em algum desses locais"
  exit 1
fi

# Limpa destino anterior
rm -rf "$PROJECT_PATH/.codex-kit/agents" \
       "$PROJECT_PATH/.codex-kit/skills" \
       "$PROJECT_PATH/.codex-kit/templates" \
       "$PROJECT_PATH/.codex-kit/docs"

# Copia blocos
cp -R "$AGENTS_SRC" "$PROJECT_PATH/.codex-kit/agents"
cp -R "$SKILLS_SRC" "$PROJECT_PATH/.codex-kit/skills"
cp -R "$TEMPLATES_SRC" "$PROJECT_PATH/.codex-kit/templates"

# Docs (opcional)
mkdir -p "$PROJECT_PATH/.codex-kit/docs"
if [ -d "$KIT_PATH/docs" ]; then
  cp -R "$KIT_PATH/docs/." "$PROJECT_PATH/.codex-kit/docs/"
elif [ -d "$KIT_PATH/.codex-kit/docs" ]; then
  cp -R "$KIT_PATH/.codex-kit/docs/." "$PROJECT_PATH/.codex-kit/docs/"
fi

echo "Bootstrap concluído: $PROJECT_PATH"
echo "Sources usados:"
echo "  agents:    $AGENTS_SRC"
echo "  skills:    $SKILLS_SRC"
echo "  templates: $TEMPLATES_SRC"
echo "Estrutura criada: AGENTS.md + .codex-kit/{agents,skills,templates,docs}"

if [ ! -f "$PROJECT_PATH/.gitignore" ]; then
  echo "Aviso: $PROJECT_PATH/.gitignore não existe."
  echo "       Recomenda-se ignorar .env, .env.*, *.pem, *.key e .DS_Store."
fi

for legacy_dir in agents skills templates; do
  if [ -e "$PROJECT_PATH/$legacy_dir" ]; then
    echo "Aviso: $PROJECT_PATH/$legacy_dir já existe na raiz do projeto."
    echo "       O bootstrap não usa essa pasta; revise manualmente se for resíduo de layout antigo."
  fi
done
