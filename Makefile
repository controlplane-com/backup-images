REGISTRY ?=ghcr.io/jacobecox
IMAGE    ?=cockroach-backup
TAG      ?=test

IMAGES := cockroach-backup postgres-backup redis-backup mongo-backup mysql-backup tidb-backup

_require_image:
	@test -n "$(IMAGE)" || (echo "Error: IMAGE is required. Usage: make <target> IMAGE=<$(subst $() ,|,$(IMAGES))>"; exit 1)
	@echo "$(IMAGES)" | tr ' ' '\n' | grep -qx "$(IMAGE)" || (echo "Error: unknown IMAGE '$(IMAGE)'. Valid options: $(IMAGES)"; exit 1)

_full_tag: _require_image
	$(eval FULL_TAG := $(if $(REGISTRY),$(REGISTRY)/,)$(IMAGE):$(TAG))

build: _full_tag
	docker build -t $(FULL_TAG) $(IMAGE)/

push: _full_tag
	docker push $(FULL_TAG)

build-push: _full_tag
	docker build -t $(FULL_TAG) $(IMAGE)/
	docker push $(FULL_TAG)

build-all:
	@for img in $(IMAGES); do \
		$(MAKE) build IMAGE=$$img TAG=$(TAG) REGISTRY=$(REGISTRY); \
	done

push-all:
	@for img in $(IMAGES); do \
		$(MAKE) push IMAGE=$$img TAG=$(TAG) REGISTRY=$(REGISTRY); \
	done

build-push-all:
	@for img in $(IMAGES); do \
		$(MAKE) build-push IMAGE=$$img TAG=$(TAG) REGISTRY=$(REGISTRY); \
	done

.PHONY: build push build-push build-all push-all build-push-all _require_image _full_tag
