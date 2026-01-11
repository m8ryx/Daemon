# Daemon Sections

This directory contains modular sections that are assembled into `daemon.md`.

## Structure

Each file represents one section of your daemon:

- **about.md** - Your bio and background
- **current_location.md** - Where you are right now
- **mission.md** - Your mission statement
- **telos.md** - Your TELOS framework (Problems, Missions, Goals)
- **books.md** - Your favorite books
- **movies.md** - Your favorite movies
- **daily_routine.md** - Your daily schedule and habits
- **preferences.md** - Your tools, languages, work style, values
- **predictions.md** - Your predictions about the future
- **projects.md** - Your current projects (Technical/Creative/Personal)

## How to Edit

1. **Edit the section file** you want to change:
   ```bash
   vim public/sections/projects.md
   ```

2. **Rebuild daemon.md**:
   ```bash
   make
   ```

3. **Verify it's correct**:
   ```bash
   make check
   ```

4. **Deploy** (deployment scripts automatically run `make`):
   ```bash
   ./deploy/deploy-lambda.sh
   ```

## Benefits of This Structure

✅ **Modular** - Edit one section without touching others
✅ **Version Control** - See exactly what changed in git diffs
✅ **Automation** - Can auto-generate sections from external sources
✅ **Organization** - Each section is self-contained and findable
✅ **Safety** - Pre-commit hook prevents deploying stale data

## Format Requirements

- Start each file with `[SECTION_NAME]` header
- Use bullet points (`-`) for lists
- Follow the existing format in each file
- Don't worry about blank lines - Makefile handles spacing

## Dynamic Content Ideas

You can make sections dynamic by:

- **Auto-updating location** from GPS or calendar API
- **Syncing projects** from GitHub, JIRA, or project management tool
- **Fetching books** from Goodreads API
- **Generating predictions** from a database

Just replace the static `.md` file with a script that outputs the same format!

## Commands

```bash
make           # Build daemon.md from sections
make clean     # Remove generated daemon.md
make check     # Verify daemon.md is up to date
make help      # Show all available commands
```
