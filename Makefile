REGISTRY  ?=ghcr.io/jacobecox
IMAGE     ?=cockroach-backup
TAG       ?=test
PLATFORM  ?=linux/amd64

_require_image:
	@test -n "$(IMAGE)" || (echo "Error: IMAGE is required. Usage: make <target> IMAGE=<image>"; exit 1)

_full_tag: _require_image
	$(eval FULL_TAG := $(if $(REGISTRY),$(REGISTRY)/,)$(IMAGE):$(TAG))

build: _full_tag
	docker build --platform $(PLATFORM) -t $(FULL_TAG) $(IMAGE)/

push: _full_tag
	docker push $(FULL_TAG)

build-push: _full_tag
	docker build --platform $(PLATFORM) -t $(FULL_TAG) $(IMAGE)/
	docker push $(FULL_TAG)

.PHONY: build push build-push _require_image _full_tag
