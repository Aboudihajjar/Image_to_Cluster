# ====== Config ======
CLUSTER   ?= lab
IMAGE     ?= custom-nginx
TAG       ?= v1
NAMESPACE ?= default
SERVICE   ?= custom-nginx
LOCALPORT ?= 9090
REMOTEPORT?= 80

PACKER_DIR  := packer
ANSIBLE_BIN := $(HOME)/.local/bin/ansible-playbook
PLAYBOOK    := ansible/deploy.yml

.PHONY: help check build import deploy restart status forward url logs clean all

help:
	@echo "Targets:"
	@echo "  make check    - check prerequisites (k3d/kubectl/docker/packer/ansible)"
	@echo "  make build    - build Docker image with Packer ($(IMAGE):$(TAG))"
	@echo "  make import   - import image into k3d cluster ($(CLUSTER))"
	@echo "  make deploy   - deploy with Ansible (Deployment+Service)"
	@echo "  make restart  - rollout restart deployment"
	@echo "  make status   - show k8s resources"
	@echo "  make forward  - port-forward service $(SERVICE) to localhost:$(LOCALPORT)"
	@echo "  make url      - print the URL to open in browser"
	@echo "  make logs     - show pod logs"
	@echo "  make clean    - delete k8s deployment+service"
	@echo "  make all      - build + import + deploy + restart"

check:
	@command -v docker >/dev/null || (echo "docker not found" && exit 1)
	@command -v kubectl >/dev/null || (echo "kubectl not found" && exit 1)
	@command -v k3d >/dev/null || (echo "k3d not found" && exit 1)
	@command -v packer >/dev/null || (echo "packer not found" && exit 1)
	@test -x "$(ANSIBLE_BIN)" || (echo "ansible-playbook not found at $(ANSIBLE_BIN)" && exit 1)
	@echo "OK: prerequisites found"
	@kubectl get nodes >/dev/null && echo "OK: kubectl can talk to cluster" || (echo "kubectl cannot reach cluster" && exit 1)

build:
	cd $(PACKER_DIR) && packer init . && packer build -var "image_name=$(IMAGE)" -var "image_tag=$(TAG)" .

import:
	k3d image import $(IMAGE):$(TAG) -c $(CLUSTER)

deploy:
	$(ANSIBLE_BIN) $(PLAYBOOK)

restart:
	kubectl -n $(NAMESPACE) rollout restart deployment/$(SERVICE)
	kubectl -n $(NAMESPACE) rollout status deployment/$(SERVICE)

status:
	@echo "== Deploy/Pods/Svc =="
	@kubectl -n $(NAMESPACE) get deploy,po,svc | grep -E "$(SERVICE)|NAME" || true

forward:
	@echo "Port-forward: http://localhost:$(LOCALPORT) -> svc/$(SERVICE):$(REMOTEPORT)"
	kubectl -n $(NAMESPACE) port-forward svc/$(SERVICE) $(LOCALPORT):$(REMOTEPORT)

url:
	@echo "Open your Codespaces forwarded port URL for LOCALPORT=$(LOCALPORT)"
	@echo "If using local curl:"
	@echo "  curl -s http://localhost:$(LOCALPORT) | head"

logs:
	@POD=$$(kubectl -n $(NAMESPACE) get pod -l app=$(SERVICE) -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then echo "No pod found for app=$(SERVICE)"; exit 1; fi; \
	echo "Pod: $$POD"; \
	kubectl -n $(NAMESPACE) logs $$POD --tail=200

clean:
	kubectl -n $(NAMESPACE) delete svc/$(SERVICE) --ignore-not-found
	kubectl -n $(NAMESPACE) delete deploy/$(SERVICE) --ignore-not-found

all: build import deploy restart status

