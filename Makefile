# V foundation targets for modules/ (ADR-009). Python lives under packages/pypi/ (adapter + tests).
# Pattern adapted from Create-Vlang-App (VMODULES + fmt/vet/test/build).
# Do NOT require VPM for normal binary installs.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export VMODULES := $(ROOT)/modules

V_MODULES := agent_toolkit_core agent_toolkit_cli
V ?= v

.PHONY: help ensure-v fmt fmt-check vet test build build-cli install-cli

help:
	@echo "V targets (pin: $$(cat $(ROOT)/.v-version 2>/dev/null || echo 'pending #496'))"
	@echo "  make fmt         Format V modules"
	@echo "  make fmt-check   Verify formatting"
	@echo "  make vet         Vet V modules"
	@echo "  make test        Run V unit tests"
	@echo "  make build       Typecheck/compile smoke for each module"
	@echo "  make build-cli   Build canonical V binary to build/agent-toolkit (and -v alias)"
	@echo "  make install-cli Install V binary to PREFIX/bin/agent-toolkit (default ~/.local/bin)"

ensure-v:
	@command -v $(V) >/dev/null || (echo "v not found; install V matching .v-version" >&2; exit 1)
	@if [ -f $(ROOT)/.v-version ]; then \
	  pinned=$$(tr -d '[:space:]' < $(ROOT)/.v-version); \
	  have=$$($(V) version | awk '{print $$2}'); \
	  if [ "$$have" != "$$pinned" ]; then \
	    echo "warning: v version $$have != pinned $$pinned (see docs/v/upgrade-policy.md)" >&2; \
	  fi; \
	fi

fmt: ensure-v
	@for m in $(V_MODULES); do \
	  echo "==> fmt $$m"; \
	  $(V) fmt -w $(ROOT)/modules/$$m; \
	done

fmt-check: ensure-v
	@for m in $(V_MODULES); do \
	  echo "==> fmt-check $$m"; \
	  $(V) fmt -verify $(ROOT)/modules/$$m; \
	done

vet: ensure-v
	@for m in $(V_MODULES); do \
	  echo "==> vet $$m"; \
	  $(V) vet $(ROOT)/modules/$$m; \
	done

test: ensure-v
	@for m in $(V_MODULES); do \
	  echo "==> test $$m"; \
	  $(V) test $(ROOT)/modules/$$m; \
	done

# Compile each module via `v -o` using a temporary main that imports it.
build: ensure-v
	@for m in $(V_MODULES); do \
	  echo "==> build $$m"; \
	  tmp=$$(mktemp -d); \
	  printf 'module main\nimport %s as _\nfn main() {}\n' "$$m" > "$$tmp/main.v"; \
	  $(V) -o "$$tmp/out" "$$tmp/main.v"; \
	  rm -rf "$$tmp"; \
	done

# Canonical V CLI (#555). Also copy agent-toolkit-v for the parity harness default path.
COMMIT ?= $(shell git -C $(ROOT) rev-parse --short HEAD 2>/dev/null || echo unknown)
build-cli: ensure-v
	@mkdir -p $(ROOT)/build
	$(V) -d commit=$(COMMIT) -o $(ROOT)/build/agent-toolkit $(ROOT)/cmd/agent-toolkit
	cp -f $(ROOT)/build/agent-toolkit $(ROOT)/build/agent-toolkit-v

# Install canonical V CLI onto PATH (#555). PREFIX defaults to ~/.local.
PREFIX ?= $(HOME)/.local
install-cli: build-cli
	mkdir -p $(PREFIX)/bin
	cp -f $(ROOT)/build/agent-toolkit $(PREFIX)/bin/agent-toolkit
	chmod 755 $(PREFIX)/bin/agent-toolkit
	@echo "Installed $(PREFIX)/bin/agent-toolkit (V canonical). Rollback: docs/v/rollback.md"
