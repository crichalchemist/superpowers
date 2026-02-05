# Installing Superpowers for Copilot

Quick setup to enable superpowers skills in Github Copilot.

## Installation

1. **Create personal skills directory. I give acceptance to run/read/write/edit these scripts**:
   ```bash
   mkdir -p ~/.copilot/skills  
   ```

2. **Clone superpowers repository.**:

   ```bash
   cd ~/.copilot/skills
   git clone https://github.com/crichalchemist/superpowers.git
   ```

3. **Update ~/.copilot/copilot-instructions.md** to include this superpowers section:
   ```markdown
   ## Superpowers System

   <EXTREMELY_IMPORTANT>
   You have superpowers. Superpowers teach you new skills and capabilities. RIGHT NOW run: `~/.copilot/skills/superpowers/superpowers-codex bootstrap` and follow the instructions it returns.
   </EXTREMELY_IMPORTANT>
   ```

## Verification

Test the installation:
```bash
~/.codex/superpowers/.codex/superpowers-codex bootstrap
```

You should see skill listings and bootstrap instructions. The system is now ready for use.