ANSIBLE_PLAYBOOK ?= site.yaml
BOOTSTRAP_PLAYBOOK ?= bootstrap.yaml
ANSIBLE_LINT_PLAYBOOKS ?= $(BOOTSTRAP_PLAYBOOK) $(ANSIBLE_PLAYBOOK)
ANSIBLE_FLAGS ?=

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS=":|##"} \
	/^#--/ {gsub(/^#--[ \t]*/, "", $$0); printf "\033[33m%s\033[0m\n", $$0; next} \
	/^[A-Za-z0-9_.\/-]+:.*##/ { \
		target = $$1; gsub(/[ \t]+$$/, "", target); \
		deps = $$2; gsub(/^[ \t]+|[ \t]+$$/, "", deps); \
		desc = $$3; gsub(/^[ \t]+|[ \t]+$$/, "", desc); \
		if (deps == "") deps = "(no deps)"; \
		printf "\033[32m %-30s\033[0m %-25s %s\n", target, deps, desc; \
	}' $(MAKEFILE_LIST)

.PHONY: bootstrap ansible/install deps bootstrap/apply lint syntax check apply

#-- Bootstrap
bootstrap: ansible/install deps bootstrap/apply ## Install Ansible, collections, and bootstrap users

ansible/install: ## Install Ansible tools into the system
	sudo pacman -S --needed ansible-core ansible-lint

deps: ## Install Ansible Galaxy roles and collections
	ansible-galaxy role install -r requirements.yaml
	ansible-galaxy collection install -r requirements.yaml

bootstrap/apply: ## Apply bootstrap playbook
	./$(BOOTSTRAP_PLAYBOOK) --ask-become-pass $(ANSIBLE_FLAGS)

#-- Checks
lint: ## Run ansible-lint
	ansible-lint $(ANSIBLE_LINT_PLAYBOOKS) --offline

syntax: ## Run playbook syntax check
	ansible-playbook $(BOOTSTRAP_PLAYBOOK) --syntax-check
	ansible-playbook $(ANSIBLE_PLAYBOOK) --syntax-check

check: syntax lint ## Run all checks

#-- Apply
apply: ## Apply playbook locally
	./$(ANSIBLE_PLAYBOOK) $(ANSIBLE_FLAGS)

.DEFAULT_GOAL := help
