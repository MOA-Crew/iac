.PHONY: tf-fmt tf-validate ansible-check

tf-fmt:
	cd terraform && terraform fmt -recursive

tf-validate:
	cd terraform/environments/dev && terraform init -backend=false && terraform validate

ansible-check:
	cd ansible && ansible-inventory --graph && ansible-playbook playbooks/bootstrap.yml --syntax-check && ansible-playbook playbooks/site.yml --syntax-check
