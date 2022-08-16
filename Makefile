SHELL := /bin/bash

CUSTOMER ?= com.gft.tsbo
PROJECT ?= com.gft.tsbo.source
MODULE ?= application
COMPONENT ?= ms-measure
TARGET ?= $(PROJECT).$(MODULE).$(COMPONENT)

CP ?= cp -pv
MKDIR ?= mkdir -p
LN ?= ln
RM ?= rm
ECHO ?= echo
DOCKER ?= docker

GIT_HOST ?= github.com
GO_PROJECT := $(shell ( $(ECHO) "$(PROJECT)" | sed 's/\./-/g' ) )
TIMESTAMP ?= $(shell date +%Y%m%d%H%M%S)
GITHASH ?= $(shell ( git rev-parse HEAD 2>/dev/null || ( $(ECHO) 'unknown' ; exit 0 ) ) ) 
_GITHASH := $(shell ( $(ECHO) "$(GITHASH)" | sed 's/^ *//; s/  *$$//; s/  */\\|/g') )

SRCS:=$(shell find . -name "*.go" )

GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOMOD=$(GOCMD) mod
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get

BUILD_DIR ?= ./build/
BIN_DIR   ?= $(BUILD_DIR)/bin
OBJ_DIR   ?= $(BUILD_DIR)/obj

DOCKER_DIR   ?= $(BUILD_DIR)/docker
DOCKER_VARIANT ?= alpine

all: bin

.PHONY: clean docker dist dep lib include distclean bin

bin: $(BIN_DIR)/$(TARGET)
lib:
include:


$(BIN_DIR)/$(TARGET): $(SRCS) Makefile go.mod go.sum
	@$(ECHO) "### GO  /BIN   $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(MKDIR) "$(BIN_DIR)" "$(OBJ_DIR)"
	@$(GOBUILD) -tags osusergo,netgo \
	  -ldflags "\
	    -linkmode external \
	    -extldflags \
	    -static \
	    -X github.com/com-gft-tsbo-source/go-common/ms-framework/dispatcher._build_component="$(COMPONENT)" \
	    -X github.com/com-gft-tsbo-source/go-common/ms-framework/dispatcher._build_module="$(MODULE)" \
	    -X github.com/com-gft-tsbo-source/go-common/ms-framework/dispatcher._build_project="$(PROJECT)" \
	    -X github.com/com-gft-tsbo-source/go-common/ms-framework/dispatcher._build_customer="$(CUSTOMER)" \
	    -X github.com/com-gft-tsbo-source/go-common/ms-framework/dispatcher._build_stamp="$(TIMESTAMP)" \
	    -X github.com/com-gft-tsbo-source/go-common/ms-framework/dispatcher._build_commit="$(_GITHASH)" \
	  " \
	  -a \
	  -o "$@" \
	  "cmd/main.go"
	@if [ ! -z "$(DIST_DIR)" ] ; then $(CP) "$(BIN_DIR)/$(TARGET)" "$(DIST_DIR)" ; fi

go.mod:
	@go mod init "$(GIT_HOST)/$(GO_PROJECT)/go-$(COMPONENT)"

go.sum: go.mod
	@go mod tidy

ls:
	@$(ECHO) "### GO  /LS    $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@ls -l $(BIN_DIR)/$(TARGET) 2>/dev/null
	@if [ ! -z "$(DIST_DIR)" ] ; then ls -l "$(DIST_DIR)/$(TARGET)" 2>/dev/null ; fi

docker-ls:
	@$(ECHO) "### GO  /DOLS  $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@(ls -l "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" 2>/dev/null && cat "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" && $(ECHO) ) ; exit 0
#	@$(ECHO) "# docker image ls --filter 'label=PROJECT=$(PROJECT)' --filter 'label=COMPONENT=$(COMPONENT)' --filter 'label=MODULE=$(MODULE)' --filter 'label=CUSTOMER=$(CUSTOMER)' --format='{{.ID}} {{.Repository}}:{{.Tag}}'"
	@while read img imgname ; do \
		$(ECHO) "I $$img $$imgname" ; \
		while read id state name image ; do \
			printf 'C %-7s %-10s %-20s %s\n' "$$id" "$$state" "$$name" "$$image" ; \
		done < <( $(DOCKER) container ls --filter "ancestor=$$img" --format='{{.ID}} {{.State}} {{.Names}} {{.Image}}'  | sort ) ; \
	done < <($(DOCKER) image ls --filter "label=PROJECT=$(PROJECT)" --filter "label=COMPONENT=$(COMPONENT)" --filter "label=MODULE=$(MODULE)" --filter "label=CUSTOMER=$(CUSTOMER)" --format='{{.ID}} {{.Repository}}:{{.Tag}}' | sort -k 2)

dist:
	@if [ ! -z "$(DIST_DIR)" ] ; then $(CP) "$(BIN_DIR)/$(TARGET)" "$(DIST_DIR)" ; fi

docker: docker-$(DOCKER_VARIANT)
docker-$(DOCKER_VARIANT): $(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid

$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid: Dockerfile-$(DOCKER_VARIANT) \
	                             $(SRCS) \
	                             Makefile
	@$(ECHO) "### GO  /DOCK  $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@if [ -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ] ; then i=$$( cat "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ); $(DOCKER) image rm -f $$i ; rm -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid"  2>/dev/null ; fi
	@$(MKDIR) "$(DOCKER_DIR)" 
	@$(DOCKER) image build -f ./Dockerfile-$(DOCKER_VARIANT) \
	  --build-arg GITHASH="$(_GITHASH)" \
	  --build-arg COMPONENT=$(COMPONENT) \
	  --build-arg MODULE=$(MODULE) \
	  --build-arg PROJECT=$(PROJECT) \
	  --build-arg CUSTOMER=$(CUSTOMER) \
	  --tag $(TARGET):base \
	  --label GITHASH="$(_GITHASH)" \
	  --label COMPONENT=$(COMPONENT) \
	  --label MODULE=$(MODULE) \
	  --label PROJECT=$(PROJECT) \
	  --label CUSTOMER=$(CUSTOMER) \
	  --iidfile "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" \
	  .

clean:
	@$(ECHO) "### GO  /CLEAN $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(RM) -rf $(BIN_DIR)/$(TARGET) $(OBJ_DIR)
	@$(MKDIR) $(BIN_DIR) $(OBJ_DIR)

docker-clean:
	@$(ECHO) "### GO  /DOCLN $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@while read img imgname ; do \
		while read id state name image ; do \
			printf 'C %-7s %-10s %-20s %s\n' "$$id" "$$state" "$$name" "$$image" ; \
			$(DOCKER) container stop --time 5 "$$id" ; \
		done < <( $(DOCKER) container ls --filter "ancestor=$$img" --format='{{.ID}} {{.State}} {{.Names}} {{.Image}}'  | sort ) ; \
		$(ECHO) "I $$img $$imgname" ; \
		$(DOCKER) image rm -f $$img ; \
		done < <($(DOCKER) image ls --filter "label=PROJECT=$(PROJECT)" --filter "label=COMPONENT=$(COMPONENT)" --filter "label=MODULE=$(MODULE)" --filter "label=CUSTOMER=$(CUSTOMER)" --format='{{.ID}} {{.Repository}}:{{.Tag}}' "$(TARGET):base" | sort -k 2)
	@if [ -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ] ; then i=$$( cat "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ); $(DOCKER) image rm -f $$i 2>/dev/null ; rm -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid"  2>/dev/null ; fi

distclean:
	@$(ECHO) "### GO  /DICLN $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(RM) -rf $(BIN_DIR)/$(TARGET) $(OBJ_DIR)
	@$(MKDIR) $(BIN_DIR) $(OBJ_DIR)

docker-distclean: docker-clean
	@$(ECHO) "### GO  /DDICL $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"

test:
	@$(ECHO) "### GO  /TEST  $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(ECHO) "GITHASH: $(_GITHASH)"
	
docker-test:
	@$(ECHO) "### GO  /DOTST $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(ECHO) "GITHASH: $(_GITHASH)"
-include $(DEPS)
