# Makefile for k8s-cross-cluster project

PLUGIN_NAME=k8s_cross

all: build

# Clone CoreDNS repository to current directory
clone-coredns: ## init and update the submodule(coredns)
	git submodule update --init --remote;

link-plugin: ## create the symlink in coredns/plugin
	cd coredns/plugin &&\
	if [ ! -e ./"${PLUGIN_NAME}" ]; then \
		ln -s ../../ ./"${PLUGIN_NAME}"; \
	fi


register-plugin: link-plugin ## register this plugin into coredns
	cd coredns &&\
	grep -qxF ${PLUGIN_NAME}:${PLUGIN_NAME} plugin.cfg || echo ${PLUGIN_NAME}:${PLUGIN_NAME} >> plugin.cfg &&\
	go generate

build: clone-coredns register-plugin ## build the coredns with this plugin
	cd coredns &&\
	make

.PHONY: clone-coredns link-plugin register-plugin build

help: ## Show this help
	@echo ""
	@echo "Choose a target:"
	@echo ""
	@grep -hE '^[0-9a-zA-Z_-]+:.*?## .*$$' ${MAKEFILE_LIST} | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[0;34m%-15s\033[m %s\n", $$1, $$2}'
	@echo ""
.PHONY: help

.DEFAULT_GOAL := help
