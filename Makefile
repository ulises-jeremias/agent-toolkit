# Thin forwarder to make.vsh (V-first tooling; vlib `build` tasks).
# Prefer: v run make.vsh <target>   (or ./make after `compile-make`)
# Kept so existing `make test` / `make build-cli` muscle memory and CI keep working.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export VMODULES := $(ROOT)/modules
V ?= v

.PHONY: help ensure-v fmt fmt-check vet test build build-cli install-cli compile-make

help fmt fmt-check vet test build build-cli install-cli compile-make:
	@$(V) run $(ROOT)/make.vsh $@
