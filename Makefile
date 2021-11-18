CUSTOMER ?= com.gft.deuba
PROJECT ?= com.gft.deuba.unity.release-1
MODULE ?= application
COMPONENT ?= ms-measure
TARGET ?= $(PROJECT).$(MODULE).$(COMPONENT)

TIMESTAMP ?= $(shell date +%Y%m%d%H%M%S)
GITHASH := $(shell ( echo "$(GITHASH)" | sed 's/  */\n/g' ; git rev-parse HEAD  ) | sort -u )
_GITHASH := $(shell ( echo "$(GITHASH)" | sed 's/^ *//; s/  *$$//; s/  */\\|/g') )

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

CP ?= cp -pv
MKDIR ?= mkdir -p
LN ?= ln
RM ?= rm

all: bin

.PHONY: clean docker dist dep lib include distclean bin

bin: $(BIN_DIR)/$(TARGET)
lib:
include:

$(BIN_DIR)/$(TARGET): $(SRCS) Makefile go.mod go.sum
	@$(MKDIR) "$(BIN_DIR)" "$(OBJ_DIR)"
	$(GOBUILD) -tags osusergo,netgo \
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
	@if [ ! -z "$(DIST_DIR)" ] ; then $(CP) -v "$(BIN_DIR)/$(TARGET)" "$(DIST_DIR)" ; fi

dist:
	@if [ ! -z "$(DIST_DIR)" ] ; then $(CP) -v "$(BIN_DIR)/$(TARGET)" "$(DIST_DIR)" ; fi

dep:

docker: docker-$(DOCKER_VARIANT)
docker-$(DOCKER_VARIANT): $(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid

$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid: Dockerfile-$(DOCKER_VARIANT) \
	                             $(SRCS) \
	                             Makefile
	@if [ -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ] ; then i=$$( cat "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ); docker image rm -f $$i ; rm -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid"  2>/dev/null ; fi
	@$(MKDIR) "$(DOCKER_DIR)" 
	@docker image build -f ./Dockerfile-$(DOCKER_VARIANT) \
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
docker-clean:
	@if [ -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ] ; then i=$$( cat "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid" ); docker image rm -f $$i ; rm -f "$(DOCKER_DIR)/$(TARGET)-$(DOCKER_VARIANT).iid"  2>/dev/null ; fi
clean:
	$(RM) -rf $(BIN_DIR)/$(TARGET) $(OBJ_DIR)
	$(MKDIR) $(BIN_DIR) $(OBJ_DIR)

distclean:
	$(RM) -rf $(BIN_DIR)/$(TARGET) $(OBJ_DIR)
	$(MKDIR) $(BIN_DIR) $(OBJ_DIR)

test:
	@echo "GITHASH: $(_GITHASH)"
	
-include $(DEPS)
