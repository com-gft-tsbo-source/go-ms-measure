SHELL := /bin/bash

include .makeinfo
include .makeproject

TARGET ?= $(PROJECT).$(MODULE).$(COMPONENT)

CP ?= cp -pv
LS ?= ls
CAT ?= cat
MKDIR ?= mkdir -p
LN ?= ln
RM ?= rm
ECHO ?= echo
PRINTF ?= printf
DOCKER ?= docker

TIMESTAMP ?= $(shell date +%Y%m%d%H%M%S)
GITHASH ?= $(shell ( git rev-parse HEAD 2>/dev/null || ( $(ECHO) 'unknown' ; exit 0 ) ) ) 
_GITHASH := $(shell ( $(ECHO) "$(GITHASH)" | sed 's/^ *//; s/  *$$//; s/  */\\|/g') )

BUILD_DIR ?= build
GO_PROJECT := $(shell ( $(ECHO) "$(PROJECT)" | sed 's/\./-/g' ) )

GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOMOD=$(GOCMD) mod
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get

BIN_DIR   ?= $(BUILD_DIR)/bin
OBJ_DIR   ?= $(BUILD_DIR)/obj

PATH_BASE      ?= .
DOCKER_DIR     ?= $(BUILD_DIR)/docker
DOCKER_VARIANT ?= alpine
DOCKER_SUFFIX  ?= base
DOCKER_IID     ?= $(DOCKER_DIR)/$(TARGET)-$(DOCKER_SUFFIX)-$(DOCKER_VARIANT).iid
DOCKER_IMAGE   ?= $(TARGET):$(DOCKER_SUFFIX)
DOCKER_FILE    ?= Dockerfile-$(DOCKER_VARIANT)

include .makesrc

all: bin

.PHONY: clean docker dist dep lib include distclean bin _buildinfo _dockerinfo

bin: _buildinfo $(BIN_DIR)/$(TARGET)
lib:
include:

_buildinfo:
	@$(ECHO) "### GO  /INFO  $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(ECHO) "CUSTOMER       '$(CUSTOMER)'" 
	@$(ECHO) "PROJECT        '$(PROJECT)'" 
	@$(ECHO) "COMPONENT      '$(COMPONENT)'" 
	@$(ECHO) "MODULE         '$(MODULE)'" 
	@$(ECHO) "TIMESTAMP      '$(TIMESTAMP)'" 
	@$(ECHO) "GITHASH        '$(GITHASH)'" 


_dockerinfo: _buildinfo
	@$(ECHO) "DOCKER_DIR     '$(DOCKER_DIR)'"
	@$(ECHO) "DOCKER_VARIANT '$(DOCKER_VARIANT)'"
	@$(ECHO) "DOCKER_SUFFIX  '$(DOCKER_SUFFIX)'"
	@$(ECHO) "DOCKER_IID     '$(DOCKER_IID)'"
	@$(ECHO) "DOCKER_IMAGE   '$(DOCKER_IMAGE)'"
	@$(ECHO) "DOCKER_FILE    '$(DOCKER_FILE)'"
	@$(ECHO) 

include .makebuild

ls:
	@$(ECHO) "### GO  /LS    $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(LS) -l $(BIN_DIR)/$(TARGET) 2>/dev/null || exit 0
	@($(LS) -l "$(DOCKER_IID)" 2>/dev/null && cat "$(DOCKER_IID)" && $(ECHO) ) ; exit 0

docker-ls:
	@$(ECHO) "### GO  /DOLS  $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@($(LS) -l "$(DOCKER_IID)" 2>/dev/null && cat "$(DOCKER_IID)" && $(ECHO) ) ; exit 0
	@while read img imgname ; do \
		$(ECHO) "I $$img $$imgname" ; \
		while read id state name image ; do \
			$(PRINTF) 'C %-7s %-10s %-20s %s\n' "$$id" "$$state" "$$name" "$$image" ; \
		done < <( $(DOCKER) container ls --filter "ancestor=$$img" --format='{{.ID}} {{.State}} {{.Names}} {{.Image}}'  | sort ) ; \
	done < <($(DOCKER) image ls --filter "label=PROJECT=$(PROJECT)" --filter "label=COMPONENT=$(COMPONENT)" --filter "label=MODULE=$(MODULE)" --filter "label=CUSTOMER=$(CUSTOMER)" --format='{{.ID}} {{.Repository}}:{{.Tag}}' | sort -k 2)

dist:
	@if [ ! -z "$(DIST_DIR)" ] ; then $(CP) "$(BIN_DIR)/$(TARGET)" "$(DIST_DIR)" ; fi

docker: docker-$(DOCKER_VARIANT)
docker-$(DOCKER_VARIANT): $(DOCKER_IID)

$(DOCKER_IID): _dockerinfo $(DOCKER_FILE) \
	                             $(SRCS) \
	                             Makefile
	@$(ECHO) "### GO  /DOCK  $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@if [ -f "$(DOCKER_IID)" ] ; then i=$$( cat "$(DOCKER_IID)" ); $(DOCKER) image rm -f $$i ; rm -f "$(DOCKER_IID)"  2>/dev/null ; fi
	@$(MKDIR) "$(DOCKER_DIR)" 
	@$(DOCKER) image build -f ./$(DOCKER_FILE) \
	  --build-arg GITHASH="$(_GITHASH)" \
	  --build-arg COMPONENT=$(COMPONENT) \
	  --build-arg MODULE=$(MODULE) \
	  --build-arg PROJECT=$(PROJECT) \
	  --build-arg CUSTOMER=$(CUSTOMER) \
	  --tag $(DOCKER_IMAGE) \
	  --label GITHASH="$(_GITHASH)" \
	  --label COMPONENT=$(COMPONENT) \
	  --label MODULE=$(MODULE) \
	  --label PROJECT=$(PROJECT) \
	  --label CUSTOMER=$(CUSTOMER) \
	  --iidfile "$(DOCKER_IID)" \
	  .

clean:
	@$(ECHO) "### GO  /CLEAN $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@$(RM) -rf $(BIN_DIR)/$(TARGET) $(OBJ_DIR)
	@$(MKDIR) $(BIN_DIR) $(OBJ_DIR)

docker-clean:
	@$(ECHO) "### GO  /DOCLN $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"
	@while read img imgname ; do \
		while read id state name image ; do \
			$(PRINTF) 'C %-7s %-10s %-20s %s\n' "$$id" "$$state" "$$name" "$$image" ; \
			$(DOCKER) container stop --time 5 "$$id" ; \
		done < <( $(DOCKER) container ls --filter "ancestor=$$img" --format='{{.ID}} {{.State}} {{.Names}} {{.Image}}'  | sort ) ; \
		$(ECHO) "I $$img $$imgname" ; \
		$(DOCKER) image rm -f $$img ; \
		done < <($(DOCKER) image ls --filter "label=PROJECT=$(PROJECT)" --filter "label=COMPONENT=$(COMPONENT)" --filter "label=MODULE=$(MODULE)" --filter "label=CUSTOMER=$(CUSTOMER)" --format='{{.ID}} {{.Repository}}:{{.Tag}}' "$(DOCKER_IMAGE)" | sort -k 2)
	@if [ -f "$(DOCKER_IID)" ] ; then i=$$( cat "$(DOCKER_IID)" ); $(DOCKER) image rm -f $$i 2>/dev/null ; rm -f "$(DOCKER_IID)"  2>/dev/null ; fi

distclean: clean
	@$(ECHO) "### GO  /DICLN $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"

docker-distclean: docker-clean
	@$(ECHO) "### GO  /DDICL $(PROJECT).$(MODULE).$(COMPONENT) - $(DOCKER_VARIANT)"

