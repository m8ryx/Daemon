# Daemon Build System
# Assembles daemon.md from modular section files

SECTIONS_DIR = public/sections
OUTPUT = public/daemon.md

# Section files in order
SECTIONS = \
	about.md \
	current_location.md \
	mission.md \
	telos.md \
	books.md \
	movies.md \
	daily_routine.md \
	preferences.md \
	predictions.md \
	projects.md

# Full paths to section files
SECTION_FILES = $(addprefix $(SECTIONS_DIR)/, $(SECTIONS))

.PHONY: all clean help check

# Default target
all: $(OUTPUT)

# Build daemon.md from sections
$(OUTPUT): $(SECTION_FILES)
	@echo "🔨 Building daemon.md from $(words $(SECTIONS)) sections..."
	@echo "# DAEMON DATA FILE" > $@
	@echo "" >> $@
	@echo "This file contains the public information for a Daemon personal API." >> $@
	@echo "Edit this file to customize your daemon." >> $@
	@echo "" >> $@
	@echo "Format: Section headers are marked with [SECTION_NAME]" >> $@
	@echo "Content follows until the next section." >> $@
	@echo "" >> $@
	@echo "---" >> $@
	@echo "" >> $@
	@for section in $(SECTIONS); do \
		cat $(SECTIONS_DIR)/$$section >> $@; \
		echo "" >> $@; \
	done
	@echo "✅ Built $(OUTPUT) ($(shell wc -l < $(OUTPUT)) lines)"

# Clean generated file
clean:
	@echo "🧹 Cleaning generated files..."
	@rm -f $(OUTPUT)
	@echo "✅ Cleaned"

# Check if daemon.md is up to date
check:
	@if [ ! -f $(OUTPUT) ]; then \
		echo "❌ $(OUTPUT) does not exist. Run 'make' to build it."; \
		exit 1; \
	fi
	@NEWER=$$(find $(SECTIONS_DIR) -type f -name '*.md' -newer $(OUTPUT) 2>/dev/null | wc -l); \
	if [ $$NEWER -gt 0 ]; then \
		echo "❌ $(OUTPUT) is out of date ($$NEWER section(s) modified). Run 'make' to rebuild it."; \
		exit 1; \
	fi; \
	echo "✅ $(OUTPUT) is up to date"

# Help
help:
	@echo "Daemon Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make        - Build daemon.md from section files"
	@echo "  make clean  - Remove generated daemon.md"
	@echo "  make check  - Verify daemon.md is up to date"
	@echo "  make help   - Show this help message"
	@echo ""
	@echo "Section files ($(words $(SECTIONS))):"
	@for section in $(SECTIONS); do \
		echo "  - $(SECTIONS_DIR)/$$section"; \
	done
