.DEFAULT_GOAL := help
SHELL := /bin/bash


help: ## This help panel.
	@IFS=$$'\n' ; \
	help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##/:/'`); \
	printf "%-30s %s\n" "DevOps console for Project Jetson" ; \
	printf "%-30s %s\n" "==================================" ; \
	printf "%-30s %s\n" "" ; \
	printf "%-30s %s\n" "Target" "Help" ; \
	printf "%-30s %s\n" "------" "----" ; \
	for help_line in $${help_lines[@]}; do \
        IFS=$$':' ; \
        help_split=($$help_line) ; \
        help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
        help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
        printf '\033[36m'; \
        printf "%-30s %s" $$help_command ; \
        printf '\033[0m'; \
        printf "%s\n" $$help_info; \
    done

%:      # thanks to chakrit
	@:    # thanks to Wi.lliam Pursell


bootstrap-environment: requirements bootstrap-environment-message ## Bootstrap development environment!

requirements: requirements-bootstrap ## Install requirements on workstation

requirements-bootstrap: ## Prepare basic packages on workstation
	workflow/requirements/macOS/bootstrap
	source ~/.bash_profile && rbenv install --skip-existing 2.2.
	source ~/.bash_profile && ansible-galaxy install -r workflow/requirements/macOS/ansible/requirements.yml
	ansible-playbook -i "localhost," workflow/requirements/generic/ansible/playbook.yml --tags "hosts" --ask-become-pass
	source ~/.bash_profile && ansible-playbook -i "localhost," workflow/requirements/macOS/ansible/playbook.yml --ask-become-pass
	source ~/.bash_profile && $(SHELL) -c 'cd workflow/requirements/macOS/docker; . ./daemon_check.sh'

requirements-docker: ## Prepare Docker on workstation
	source ~/.bash_profile && $(SHELL) -c 'cd workflow/requirements/macOS/docker; . ./daemon_check.sh'

requirements-hosts: ## Prepare /etc/hosts on workstation
	ansible-playbook -i "localhost," workflow/requirements/generic/ansible/playbook.yml --tags "hosts" --ask-become-pass

requirements-packages: ## Install packages on workstation
	ansible-playbook -i "localhost," workflow/requirements/macOS/ansible/playbook.yml --ask-become-pass

requirements-ansible: ## Install ansible requirements on workstation for provisioning jetson
	ansible-galaxy install -r workflow/provision/requirements.yml

bootstrap-environment-message: ## Echo a message that the app installation is happening now
	@echo ""
	@echo ""
	@echo "Welcome!"
	@echo ""
	@echo "1) Please follow the instructions to fully install and start Docker - Docker started up when its Icon ("the whale") is no longer moving."
	@echo ""
	@echo "2) Click on the Docker icon, goto Preferences / Advanced, set Memory to at least 4GiB and click Apply & Restart."
	@echo ""
	@echo ""


image-download: ## Download Nvidia Jetpack into workflow/provision/image
	cd workflow/provision/image && wget -N -O jetson-nano-sd.zip https://developer.nvidia.com/jetson-nano-sd-card-image-r322 && unzip -o *.zip && rm -f jetson-nano-sd.zip

setup-access-secure: ## Allow passwordless ssh and sudo, disallow ssh with password
	ssh-copy-id -i ~/.ssh/id_rsa provision@nano-one.local
	cd workflow/provision && ansible-playbook main.yml --tags "access_secure" -b -K


provision: ## Provision the Nvidia Jetson Nano
	cd workflow/provision && ansible-playbook main.yml --tags "provision"

provision-base: ## Provision base
	cd workflow/provision && ansible-playbook main.yml --tags "base"

provision-kernel: ## Compile custom kernel for docker - takes ca. 60 minutes
	cd workflow/provision && ansible-playbook main.yml --tags "kernel"

provision-firewall: ## Provision firewall
	cd workflow/provision && ansible-playbook main.yml --tags "firewall"

provision-lxde: ## Provision LXDE
	cd workflow/provision && ansible-playbook main.yml --tags "lxde"

provision-vnc: ## Provision VNC
	cd workflow/provision && ansible-playbook main.yml --tags "vnc"

provision-xrdp: ## Provision XRDP
	cd workflow/provision && ansible-playbook main.yml --tags "xrdp"

provision-k8s: ## Provision Kubernetes
	cd workflow/provision && ansible-playbook main.yml --tags "k8s"

provision-build: ## Provision build environment
	cd workflow/provision && ansible-playbook main.yml --tags "build"

provision-swap: ## Provision swap
	cd workflow/provision && ansible-playbook main.yml --tags "swap"

provision-performance-mode: ## Set performace mode
	cd workflow/provision && ansible-playbook main.yml --tags "performance_mode"

provision-test: ## Install tools for testing
	cd workflow/provision && ansible-playbook main.yml --tags "test"


nano-one-ssh: ## ssh to nano-one as user provision
	ssh provision@nano-one.local

nano-one-ssh-build: ## ssh to nano-one as user build
	ssh build@nano-one.local

nano-one-reboot: ## reboot nano-one
	ssh build@nano-one.local "sudo shutdown -r now"

nano-one-exec: ## exec command on nano-one - you must pass in arguments e.g. tegrastats
	ssh build@nano-one.local $(filter-out $@,$(MAKECMDGOALS))

nano-one-cuda-ml-deb-repack: ## Repack libcudnn and TensorRT libraries inc. python bindings on nano and create local repository
	workflow/deploy/tools/nano-cuda-ml-deb-repack


nano-one-ssd-id-serial-short-show: ## Show short serial id of /dev/sda assuming the SSD is the only block device connected to the nano via USB
	ssh provision@nano-one.local "udevadm info /dev/sda | grep ID_SERIAL_SHORT"

nano-one-ssd-prepare: ## DANGER: Assign stable device name to SSD, reboot, wipe SSD, create boot partition, create ext4 filesystem
	cd workflow/provision && ansible-playbook main.yml --tags "ssd_prepare"

nano-one-ssd-uuid-show: ## Show UUID of /dev/ssd1
	ssh provision@nano-one.local "udevadm info /dev/ssd1 | grep ID_FS_UUID_ENC"

nano-one-ssd-activate: ## DANGER: Update the boot menu to include the SSD as default boot device and reboot
	cd workflow/provision && ansible-playbook main.yml --tags "ssd_activate"


k8s-proxy: ## Open proxy
	kubectl proxy

k8s-dashboard-bearer-token-show: ## Show dashboard bearer token
	workflow/k8s/dashboard-bearer-token-show

k8s-dashboard-open: ## Open Dashboard
	python -mwebbrowser http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/overview?namespace=default

k8s-token-create: ## Create token to join cluster
	ssh root@max-one.local kubeadm token create


ml-base-build-and-test: ## Build, push and test ml base image for Docker on nano with cuda and tensorflow
	cd workflow/deploy/ml-base && skaffold build
	workflow/deploy/tools/container-structure-test ml-base

ml-base-publish: ## Publish latest ml base image on nano to Docker Hub given credentials in .docker-hub.auth
	workflow/deploy/tools/publish ml-base $(shell sed '1q;d' .docker-hub.auth)  $(shell sed '2q;d' .docker-hub.auth)


tensorflow-serving-base-build-and-test: ## Build, push and test ml tensorflow-serving image for Docker on nano extending ml-base with TensorFlow *Serving*
	cd workflow/deploy/tensorflow-serving-base && skaffold build
	workflow/deploy/tools/container-structure-test tensorflow-serving-baser

tensorflow-serving-base-publish: ## Publish latest tensorflow-serving base image on nano to Docker Hub given credentials in .docker-hub.auth
	workflow/deploy/tools/publish tensorflow-serving-base $(shell sed '1q;d' .docker-hub.auth)  $(shell sed '2q;d' .docker-hub.auth)


device-query-build-and-test: ## Build and test device-query
	cd workflow/deploy/device-query && skaffold build
	workflow/deploy/tools/container-structure-test device-query

device-query-deploy: ## Build and deploy device query
	kubectl create namespace jetson-device-query || true
	cd workflow/deploy/device-query && skaffold run

device-query-deploy-docker-hub-parent: ## Build and deploy device query, pull ml-base image from Docker Hub
	kubectl create namespace jetson-device-query || true
	cd workflow/deploy/device-query && skaffold run -p parent-docker-hub

device-query-deploy-docker-hub: ## Deploy device query, pull image from Docker Hub
	kubectl create namespace jetson-device-query || true
	cd workflow/deploy/device-query && skaffold run -p docker-hub

device-query-log-show: ## Show log of pod
	workflow/deploy/tools/log-show device-query

device-query-dev: ## Enter build, deploy, tail, watch cycle for device query
	kubectl create namespace jetson-device-query || true
	cd workflow/deploy/device-query && skaffold dev

device-query-dev-docker-hub-parent: ## Enter build, deploy, tail, watch cycle for device query, pull ml-base image from Docker Hub
	kubectl create namespace jetson-device-query || true
	cd workflow/deploy/device-query && skaffold dev -p docker-hub-parent

device-query-publish: ## Publish latest device-query image on nano to Docker Hub given credentials in .docker-hub.auth
	workflow/deploy/tools/publish device-query $(shell sed '1q;d' .docker-hub.auth)  $(shell sed '2q;d' .docker-hub.auth)

device-query-delete: ## Delete device query deployment
	cd workflow/deploy/device-query && skaffold delete
	kubectl delete namespace jetson-device-query || true


jupyter-build-and-test: ## Build and test jupyter
	cd workflow/deploy/jupyter && skaffold build
	workflow/deploy/tools/container-structure-test jupyter

jupyter-deploy: ## Build and deploy jupyter
	kubectl create namespace jetson-jupyter || true
	kubectl create secret generic jupyter.polarize.ai --from-file workflow/deploy/jupyter/.basic-auth --namespace=jetson-jupyter || true
	cd workflow/deploy/jupyter && skaffold run

jupyter-deploy-docker-hub-parent: ## Build and deploy jupyter, pull ml-base image from Docker Hub
	kubectl create namespace jetson-jupyter || true
	cd workflow/deploy/jupyter && skaffold run -p parent-docker-hub

jupyter-deploy-docker-hub: ## Deploy jupyter, pull image from Docker Hub
	kubectl create namespace jetson-jupyter || true
	cd workflow/deploy/jupyter && skaffold run -p docker-hub

jupyter-open: ## Open browser pointing to jupyter notebook
	python -mwebbrowser http://jupyter.nano-one.local/

jupyter-log-show: ## Show log of pod
	workflow/deploy/tools/log-show jupyter

jupyter-dev: ## Enter build, deploy, tail, watch cycle for jupyter
	kubectl create namespace jetson-jupyter || true
	kubectl create secret generic jupyter.polarize.ai --from-file workflow/deploy/jupyter/.basic-auth --namespace=jetson-jupyter || true
	cd workflow/deploy/jupyter && skaffold dev

jupyter-dev-docker-hub-parent: ## Enter build, deploy, tail, watch cycle for jupyter, pull ml-base image from Docker Hub
	kubectl create namespace jupyter-query || true
	cd workflow/deploy/jupyter && skaffold dev -p docker-hub-parent

jupyter-publish: ## Publish latest jupyter image on nano to Docker Hub given credentials in .docker-hub.auth
	workflow/deploy/tools/publish jupyter $(shell sed '1q;d' .docker-hub.auth)  $(shell sed '2q;d' .docker-hub.auth)

jupyter-delete: ## Delete jupyter deployment
	cd workflow/deploy/jupyter && skaffold delete
	kubectl delete namespace jetson-jupyter || true



tensorflow-serving-build-and-test: ## Build and test tensorflow-serving
	cd workflow/deploy/tensorflow-serving && skaffold build
	workflow/deploy/tools/container-structure-test tensorflow-serving

tensorflow-serving-deploy: ## Build and deploy tensorflow-serving
	kubectl create namespace jetson-tensorflow-serving || true
	kubectl create secret generic tensorflow-serving.polarize.ai --from-file workflow/deploy/tensorflow-serving/.basic-auth --namespace=jetson-tensorflow-serving || true
	cd workflow/deploy/tensorflow-serving && skaffold run

tensorflow-serving-health-check: ## Check health
	@echo "Checking health via Webservice API ..."
	@curl http://tensorflow-serving.nano-one.local/api/v1/health/healthz
	@echo ""

tensorflow-serving-docs-open: ## Open browser tabs showing API documentation of the webservice
	@echo "Opening OpenAPI documentation of Webservice API ..."
	python -mwebbrowser http://tensorflow-serving.nano-one.local/docs
	python -mwebbrowser http://tensorflow-serving.nano-one.local/redoc
	@curl http://tensorflow-serving.nano-one.local/api/v1/openapi.json
	@echo ""

tensorflow-serving-predict: ## Send prediction REST and webservice requests
	@echo "Predicting via TFS REST API ..."
	@curl -d '{"instances": [1.0, 2.0, 5.0, 10.0]}' -X POST http://tensorflow-serving.nano-one.local:8501/v1/models/half_plus_two:predict
	@echo ""
	@echo "Predicting via Webservice API accessing REST endpoint of TFS ..."
	@curl -d '{"instances": [1.0, 2.0, 5.0, 10.0]}' -X POST http://tensorflow-serving.nano-one.local/api/v1/prediction/predict
	@echo ""
	@echo "Predicting via Webservice API accessing gRPC endpoint of TFS ..."
	@curl -d '{"instances": [1.0, 2.0, 5.0, 10.0]}' -X POST http://tensorflow-serving.nano-one.local/api/v1/prediction/grpc/predict
	@echo ""

tensorflow-serving-log-show: ## Show log of pod
	workflow/deploy/tools/log-show tensorflow-serving

tensorflow-serving-dev: ## Enter build, deploy, tail, watch cycle for tensorflow-serving
	kubectl create namespace jetson-tensorflow-serving || true
	kubectl create secret generic tensorflow-serving.polarize.ai --from-file workflow/deploy/tensorflow-serving/.basic-auth --namespace=jetson-tensorflow-serving || true
	cd workflow/deploy/tensorflow-serving && skaffold dev

tensorflow-serving-publish: ## Publish latest tensorflow-serving image on nano to Docker Hub given credentials in .docker-hub.auth
	workflow/deploy/tools/publish tensorflow-serving $(shell sed '1q;d' .docker-hub.auth)  $(shell sed '2q;d' .docker-hub.auth)

tensorflow-serving-delete: ## Delete tensorflow-serving deployment
	cd workflow/deploy/tensorflow-serving && skaffold delete
	kubectl delete namespace jetson-tensorflow-serving || true


l4t-build-and-test: ## Cross-build l4t on macOS and test on nano
	cd workflow/deploy/l4t && skaffold build
	workflow/deploy/l4t/container-structure-test.mac l4t

l4t-deploy: ## Cross-build l4t on macOS and deploy
	kubectl create namespace jetson-l4t || true
	cd workflow/deploy/l4t && skaffold run

l4t-open: ## Open browser pointing to l4t notebook
	python -mwebbrowser http://l4t.nano-one.local/

l4t-log-show: ## Show log of pod
	workflow/deploy/tools/log-show l4t

l4t-dev: ## Enter cross-build, deploy, tail, watch cycle for l4t
	kubectl create namespace jetson-l4t || true
	cd workflow/deploy/l4t && skaffold dev

l4t-publish: ## Publish latest lt4 image on nano to Docker Hub given credentials in .docker-hub.auth
	workflow/deploy/tools/publish l4t $(shell sed '1q;d' .docker-hub.auth)  $(shell sed '2q;d' .docker-hub.auth)

l4t-delete: ## Delete l4t deployment
	cd workflow/deploy/l4t && skaffold delete
	kubectl delete namespace jetson-l4t || true
