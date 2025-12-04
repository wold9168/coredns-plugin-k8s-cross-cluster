# Makefile for k8s-cross-cluster project

all: build

# Clone CoreDNS repository to current directory
clone-coredns:
	git submodule update --init --remote; \

register-plugin:
	cd coredns &&\
	grep -qxF 'k8s-cross-cluster:k8s-cross-cluster' plugin.cfg || echo 'k8s-cross-cluster:k8s-cross-cluster' >> plugin.cfg &&\
	go generate

build: clone-coredns register-plugin
	cd coredns &&\
	make

.PHONY: clone-coredns register-plugin build
