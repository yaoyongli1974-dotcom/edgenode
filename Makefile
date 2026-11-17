# EdgeNode Makefile (GNU make; recipes use POSIX-compatible commands)
#
# Targets: help (default), test, test-all, lint, dist, install, clean

SH ?= sh
DIST_DIR ?= dist

# Version is extracted from the agent script; never hardcode it here.
VERSION := $(shell sed -n 's/^AGENT_VERSION="\([^"]*\)".*/\1/p' agent/edgenode-agent)

# Scripts checked by lint / shellcheck. Missing files are skipped.
LINT_FILES = agent/edgenode-agent api/cgi-bin/api tests/run-tests.sh \
             scripts/install.sh scripts/uninstall.sh

# Paths packed into the release tarball. scripts/ and LICENSE are optional
# (they may be added by later changes); everything else is required.
DIST_PATHS = agent api docs examples tests README.md CHANGELOG.md \
             $(wildcard scripts) $(wildcard LICENSE)

.DEFAULT_GOAL := help
.PHONY: help test test-all lint dist install clean

help:
	@printf 'EdgeNode Makefile targets:\n'
	@printf '  help      Show this help (default target)\n'
	@printf '  test      Run regression tests: sh tests/run-tests.sh\n'
	@printf '  test-all  Run tests under sh, dash, bash, busybox ash (missing shells skipped)\n'
	@printf '  lint      shellcheck -s sh on agent/api/tests/scripts (skipped if not installed)\n'
	@printf '  dist      Build $(DIST_DIR)/edgenode-<VERSION>.tar.gz (VERSION from agent script)\n'
	@printf '  install   Run scripts/install.sh (DESTDIR=<prefix> passes --prefix)\n'
	@printf '  clean     Remove $(DIST_DIR)/\n'
	@printf 'Variables: SH=$(SH)  DIST_DIR=$(DIST_DIR)  VERSION=$(VERSION)\n'

test:
	$(SH) tests/run-tests.sh

# Run the same suite under each interpreter. EN_SH may contain spaces
# ("busybox ash"), so it is always passed as one quoted string.
# Missing interpreters are skipped; any test failure fails the target and
# reports which interpreter failed.
test-all:
	@fail=0; \
	for interp in sh dash bash "busybox ash"; do \
		cmd=$${interp%% *}; \
		if ! command -v "$$cmd" >/dev/null 2>&1; then \
			printf 'SKIP  %s (interpreter not installed)\n' "$$interp"; \
			continue; \
		fi; \
		printf '\n== EN_SH="%s" ==\n' "$$interp"; \
		if EN_SH="$$interp" $(SH) tests/run-tests.sh; then \
			:; \
		else \
			printf 'FAIL  tests failed under interpreter: %s\n' "$$interp"; \
			fail=1; \
		fi; \
	done; \
	exit $$fail

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		rc=0; \
		for f in $(LINT_FILES); do \
			if [ -f "$$f" ]; then \
				shellcheck -s sh "$$f" || rc=1; \
			else \
				printf 'SKIP  %s (not found)\n' "$$f"; \
			fi; \
		done; \
		exit $$rc; \
	else \
		printf 'shellcheck is not installed; skipping lint (install it to enable)\n'; \
	fi

dist:
	@if [ -z "$(VERSION)" ]; then \
		printf 'ERROR: cannot extract AGENT_VERSION from agent/edgenode-agent\n' >&2; \
		exit 1; \
	fi
	@mkdir -p $(DIST_DIR)
	tar -czf $(DIST_DIR)/edgenode-$(VERSION).tar.gz $(DIST_PATHS)
	@printf 'Built %s/edgenode-%s.tar.gz\n' '$(DIST_DIR)' '$(VERSION)'

install:
	@if [ ! -f scripts/install.sh ]; then \
		printf 'ERROR: scripts/install.sh not found; nothing to install\n' >&2; \
		exit 1; \
	fi
	$(SH) scripts/install.sh $(if $(DESTDIR),--prefix $(DESTDIR))

clean:
	rm -rf $(DIST_DIR)
