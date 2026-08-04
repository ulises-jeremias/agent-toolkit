
# Create a concise Copilot CLI note
cat > $AT/profiles/copilot/README.md << 'EOF'
# GitHub Copilot Profile

## IDE Copilot (VS Code, JetBrains, vim-copilot)

Copy `copilot-instructions.md` to your project's `.github/` directory:

```bash
mkdir -p .github
cp profiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

GitHub Copilot reads `.github/copilot-instructions.md` automatically.

## Copilot CLI (`gh copilot`)

`gh copilot suggest` and `gh copilot explain` are CLI tools for shell command generation.
They do **not** read `copilot-instructions.md` — they work with the model directly.

Install: `gh extension install github/gh-copilot`

For Copilot CLI, the best practice is to use the `gh-fix-ci` and `gh-address-comments`
skills from agent-toolkit, which wrap `gh copilot` functionality.

## Install via agent-toolkit CLI

```bash
pip install agent-toolkit-cli      # or: uvx agent-toolkit-cli
agent-toolkit install --tools copilot
# Prompts for your project path and copies copilot-instructions.md
```
