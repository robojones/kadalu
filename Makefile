.PHONY: help build-grpc build-containers gen-manifest pylint prepare-release release

DOCKER_USER?=kadalu
KADALU_VERSION?=latest


help:
	@echo "    make build-grpc        - To generate grpc Python Code"
	@echo "    make build-containers  - To create server, csi and Operator containers"
	@echo "    make gen-manifest      - To generate manifest files to deploy"
	@echo "    make pylint            - To validate all Python code with Pylint"
	@echo "    make prepare-release   - Generate Manifest file and build containers for specific version and latest"
	@echo "    make release           - Publish the built container images"

build-grpc:
	python3 -m grpc_tools.protoc -I./csi/protos --python_out=csi --grpc_python_out=csi ./csi/protos/csi.proto

build-containers:
	DOCKER_USER=${DOCKER_USER} KADALU_VERSION=${KADALU_VERSION} bash build.sh

gen-manifest:
	@echo "Generating manifest files, run the following commands"
	@echo
	@mkdir -p manifests
	@DOCKER_USER=${DOCKER_USER} KADALU_VERSION=${KADALU_VERSION} \
		python3 extras/scripts/gen_manifest.py
	@cat templates/namespace.yaml > manifests/kadalu-operator.yaml
	@echo >> manifests/kadalu-operator.yaml
	@cat templates/operator.yaml >> manifests/kadalu-operator.yaml
	@echo >> manifests/kadalu-operator.yaml
	@echo "kubectl create -f manifests/kadalu-operator.yaml"

pylint:
	@cp lib/kadalulib.py csi/
	@cp lib/kadalulib.py server/
	@cp lib/kadalulib.py operator/
	-pylint-3 --disable=W0511 -s n lib/kadalulib.py
	-pylint-3 --disable=W0511 -s n server/glusterfsd.py
	-pylint-3 --disable=W0511 -s n server/quotad.py
	-pylint-3 --disable=W0511 -s n server/server.py
	-pylint-3 --disable=W0511 -s n csi/controllerserver.py
	-pylint-3 --disable=W0511 -s n csi/identityserver.py
	-pylint-3 --disable=W0511 -s n csi/main.py
	-pylint-3 --disable=W0511 -s n csi/nodeserver.py
	-pylint-3 --disable=W0511 -s n csi/volumeutils.py
	-pylint-3 --disable=W0511 -s n operator/main.py
	@rm csi/kadalulib.py
	@rm server/kadalulib.py
	@rm operator/kadalulib.py

ifeq ($(KADALU_VERSION), latest)
prepare-release:
	@echo "KADALU_VERSION can't be latest for release"
else
prepare-release:
	@DOCKER_USER=${DOCKER_USER} KADALU_VERSION=${KADALU_VERSION} \
		$(MAKE) gen-manifest
	@cp manifests/kadalu-operator.yaml \
		manifests/kadalu-operator-${KADALU_VERSION}.yaml
	@DOCKER_USER=${DOCKER_USER} KADALU_VERSION=latest \
		$(MAKE) gen-manifest
	@echo "Generated manifest file. Version: ${KADALU_VERSION}"
	@echo "Building containers(Version: ${KADALU_VERSION}).."
	@DOCKER_USER=${DOCKER_USER} KADALU_VERSION=${KADALU_VERSION} \
		$(MAKE) build-containers
	@echo "Building containers(Version: latest).."
	@DOCKER_USER=${DOCKER_USER} KADALU_VERSION=latest \
		$(MAKE) build-containers
endif

ifeq ($(KADALU_VERSION), latest)
release: prepare-release
else
release: prepare-release
	docker push ${DOCKER_USER}/kadalu-operator:${KADALU_VERSION}
	docker push ${DOCKER_USER}/kadalu-csi:${KADALU_VERSION}
	docker push ${DOCKER_USER}/kadalu-server:${KADALU_VERSION}
	docker push ${DOCKER_USER}/kadalu-operator:latest
	docker push ${DOCKER_USER}/kadalu-csi:latest
	docker push ${DOCKER_USER}/kadalu-server:latest
endif
