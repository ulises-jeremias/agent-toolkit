# Thin forwarder to make.vsh (V-first tooling). Prefer: v run make.vsh <target>
# Kept so existing `make test` / `make build-cli` muscle memory and CI keep working.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export VMODULES := $(ROOT)/modules
V ?= v

.PHONY: help ensure-v fmt fmt-check vet test build build-cli install-cli

help fmt fmt-check vet test build build-cli install-cli:
	@$(V) run $(ROOT)/make.vsh $@
