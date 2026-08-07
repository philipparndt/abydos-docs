# The site: assembled from src/ into dist/, which is what Pages serves.
#
# There is a build now because there are two pages, and two pages that share a
# palette, a header and a footer by having been copied are two pages that drift.
# Nothing is installed to run it — python3 is on macOS and on the runner.

PYTHON ?= python3
PORT   ?= 8000

.DEFAULT_GOAL := build

.PHONY: help
help: ## This list
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk -F':.*?## ' '{printf "  \033[1m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Assemble src/ into dist/
	@$(PYTHON) Scripts/build.py

.PHONY: serve
serve: build ## Build, then serve dist/ on http://localhost:$(PORT)
	@echo "==> http://localhost:$(PORT)"
	@$(PYTHON) -m http.server $(PORT) --directory dist

.PHONY: screenshots
screenshots: ## Photograph the app for the pages (THEME=abydos, SHOT=one)
	@Scripts/screenshots.sh site $(SHOT)

.PHONY: theme-shots
theme-shots: ## Photograph one scene in each theme, for themes.html
	@Scripts/screenshots.sh themes

.PHONY: shots
shots: ## Both sets
	@Scripts/screenshots.sh all

.PHONY: clean
clean: ## Remove dist/
	@rm -rf dist
	@echo "==> dist/ removed"
