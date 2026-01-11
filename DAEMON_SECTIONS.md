# Daemon Modular Section System

Your daemon.md is now built from **modular section files** for easier editing and dynamic content generation.

## Quick Start

**Edit a section:**
```bash
vim public/sections/projects.md
```

**Rebuild daemon.md:**
```bash
make
```

**Deploy:**
```bash
./deploy/deploy-lambda.sh  # Automatically runs 'make' first
```

## File Structure

```
Daemon/
├── Makefile                  # Build system
├── public/
│   ├── daemon.md            # Generated (don't edit directly!)
│   └── sections/            # Source files (edit these!)
│       ├── about.md
│       ├── current_location.md
│       ├── mission.md
│       ├── telos.md
│       ├── books.md
│       ├── movies.md
│       ├── daily_routine.md
│       ├── preferences.md
│       ├── predictions.md
│       └── projects.md
└── .git/hooks/
    └── pre-commit          # Ensures daemon.md is up to date
```

## How It Works

1. **Edit section files** in `public/sections/`
2. **Run `make`** to assemble them into `daemon.md`
3. **Git pre-commit hook** prevents committing stale daemon.md
4. **Deployment scripts** automatically run `make` before deploying

## Available Commands

```bash
make           # Build daemon.md from sections
make clean     # Remove generated daemon.md
make check     # Verify daemon.md is up to date
make help      # Show all commands
```

## Safety Features

✅ **Pre-commit hook** - Can't commit if daemon.md is out of date
✅ **Deployment check** - Scripts rebuild daemon.md before deploying
✅ **Version control** - Both sections and generated file are tracked

## Editing Workflow

### Quick Edit
```bash
vim public/sections/projects.md
make
git add public/sections/projects.md public/daemon.md
git commit -m "Update projects"
```

### Test Build
```bash
make clean    # Remove generated file
make          # Rebuild from sections
make check    # Verify it's correct
```

## Dynamic Content Examples

You can replace any `.md` file with a script that generates content:

**Example: Auto-update location**
```bash
#!/bin/bash
# public/sections/current_location.md

echo "[CURRENT_LOCATION]"
echo ""
echo "Currently in $(curl -s ipinfo.io/city), $(curl -s ipinfo.io/region)"
```

**Example: Sync projects from GitHub**
```bash
#!/bin/bash
# public/sections/projects.md

echo "[PROJECTS]"
echo ""
echo "Technical:"
gh repo list --limit 5 | while read repo rest; do
  echo "- $repo"
done
```

Make the file executable:
```bash
chmod +x public/sections/current_location.md
```

The Makefile will execute scripts instead of just concatenating them!

## Troubleshooting

**daemon.md is out of date:**
```bash
make
```

**Pre-commit hook failing:**
```bash
make check     # See what's wrong
make           # Rebuild
git add public/daemon.md
git commit
```

**Deployment failing:**
```bash
make           # Rebuild locally
make check     # Verify
./deploy/deploy-lambda.sh
```

## Benefits

✅ **Easier editing** - Change one section at a time
✅ **Better git diffs** - See exactly what changed
✅ **Dynamic generation** - Auto-update from APIs or databases
✅ **Modular updates** - Update projects without touching mission
✅ **Organization** - Each section is self-contained

## Migration Complete

Your existing daemon.md has been split into:
- ✅ 10 section files in `public/sections/`
- ✅ Makefile to assemble them
- ✅ Pre-commit hook for safety
- ✅ Updated deployment scripts

The generated `daemon.md` is identical to your original file.
