# 47monad GoMake v0.0.3
#
# =============================================================================
# ⚙️ Makefile Configuration
# =============================================================================
REPO_URL=https://raw.githubusercontent.com/47monad/gomake/refs/heads/main/Makefile
SELF_FILE=$(lastword $(MAKEFILE_LIST))

# =============================================================================
# 🎯 Project Configuration
# =============================================================================
# Project Settings
PROJECT_NAME ?= $(shell basename $(CURDIR) | sed -E 's/[-_]/ /g; s/^(.)/\U\1/g')
ORGANIZATION ?= 47monad
DESCRIPTION ?= $(PROJECT_NAME) Project
DISCLAIMER = "47monad | All rights reserved"
MAINTAINER = "47monad"

# Services
SERVICES ?= $(wildcard cmd/*)
SERVICE_PATH = cmd/$*

# Build Settings
BUILD_SYSTEM ?= local # local, ci
CI_SYSTEM ?= github # github, gitlab, jenkins
PARALLEL_JOBS ?= $(shell \
    if command -v nproc >/dev/null 2>&1; then \
        nproc; \
    elif command -v getconf >/dev/null 2>&1; then \
        getconf _NPROCESSORS_ONLN; \
    elif command -v sysctl >/dev/null 2>&1; then \
        sysctl -n hw.ncpu; \
    else \
        echo 1; \
    fi)
ENABLE_PARALLEL := $(if $(filter local,$(BUILD_SYSTEM)),true,false)

# Version Control
VERSION_STRATEGY ?= git # git, semver, date
VERSION := $(shell \
    if [ "$(VERSION_STRATEGY)" = "git" ] && git rev-parse --git-dir > /dev/null 2>&1; then \
        git describe --tags --always --dirty 2>/dev/null || echo "dev"; \
    elif [ "$(VERSION_STRATEGY)" = "semver" ]; then \
        cat VERSION 2>/dev/null || echo "0.1.0"; \
    else \
        date -u '+%Y%m%d-%H%M%S'; \
    fi)
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_TIME ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')
BUILD_BY ?= $(shell whoami)

# Go Configuration
GO ?= go
GOCMD = $(shell which go)
GOPATH ?= $(shell $(GO) env GOPATH)
GOBIN ?= $(GOPATH)/bin
GOOS ?= $(shell $(GO) env GOOS)
GOARCH ?= $(shell $(GO) env GOARCH)
CGO_ENABLED ?= 0

# Tools & Linters
GOLANGCI_LINT ?= $(GOBIN)/golangci-lint
GOFUMPT ?= $(GOBIN)/gofumpt
GODOC ?= $(GOBIN)/godoc
GOVULNCHECK ?= $(GOBIN)/govulncheck
MOCKERY ?= mockery

# Directories
ROOT_DIR ?= $(shell pwd)
CMD_DIR ?= $(ROOT_DIR)/cmd
BIN_DIR ?= $(ROOT_DIR)/bin
DIST_DIR ?= $(ROOT_DIR)/dist
DOCS_DIR ?= $(ROOT_DIR)/docs
CONFIG_DIR ?= $(ROOT_DIR)/config

# Build Configuration
BUILD_TAGS ?= 
EXTRA_TAGS ?=
ALL_TAGS = $(BUILD_TAGS) $(EXTRA_TAGS)

# Linker Flags
LD_FLAGS += -s -w
LD_FLAGS += -X '$(shell go list -m)/pkg/version.Version=$(VERSION)'
LD_FLAGS += -X '$(shell go list -m)/pkg/version.Commit=$(GIT_COMMIT)'
LD_FLAGS += -X '$(shell go list -m)/pkg/version.Branch=$(GIT_BRANCH)'
LD_FLAGS += -X '$(shell go list -m)/pkg/version.BuildTime=$(BUILD_TIME)'
LD_FLAGS += -X '$(shell go list -m)/pkg/version.BuildBy=$(BUILD_BY)'

# Performance & Debug Flags
GCFLAGS ?=
ASMFLAGS ?=

# Test Configuration
TEST_TIMEOUT ?= 5m
TEST_FLAGS ?= -v -race -cover
TEST_PACKAGES ?= $(shell $(GO) list ./... | grep -v "mocks")
COVERAGE_OUT ?= coverage.out
COVERAGE_HTML ?= $(DOCS_DIR)/reports/coverage.html
COVERAGE_THRESHOLD ?= 50
BENCH_FLAGS ?= -benchmem
BENCH_TIME ?= 2s
TEST_PATTERN ?= .
SKIP_PATTERN ?=

# =============================================================================
# 🎨 Terminal Colors & Emoji
# =============================================================================
# Colors
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
MAGENTA := \033[35m
CYAN := \033[36m
WHITE := \033[37m
BOLD := \033[1m
RESET := \033[0m

# Status Indicators
INFO := printf "$(BLUE)ℹ️  $(RESET)%s \n"
SUCCESS := printf "$(GREEN)✅ $(RESET)%s \n"
WARN := printf "$(YELLOW)⚠️  $(RESET)%s \n"
ERROR := printf "$(RED)❌ $(RESET)%s \n"
WORKING := printf "$(CYAN)🔨 $(RESET)%s \n"
DEBUG := printf "$(MAGENTA)🔍 $(RESET)%s \n"
ROCKET := printf "$(GREEN)🚀 $(RESET)%s \n"
PACKAGE := printf "$(CYAN)📦 $(RESET)%s \n"
TRASH := printf "$(YELLOW)🗑️  $(RESET)%s \n"

# =============================================================================
##@ 🎯 Core Build System
# =============================================================================
.PHONY: build
build: $(BIN_DIR) ## Build all services
	@$(WORKING) "Building project..."
	for service in $(SERVICES); do \
		@$(MAKE) build-$$service $(if $(filter true,$(ENABLE_PARALLEL)),--jobs=$(PARALLEL_JOBS)); \
	done
	@wait
	@$(SUCCESS) "Build complete!"

.PHONY: build-% 
build-%: generate ## Build a single service (% = service name)
	@$(INFO) "Building $*..."
	@if [ -f "$(BIN_DIR)/$*" ]; then \
		rm "$(BIN_DIR)/$*"; \
	fi
	@if [ -f "$(SERVICE_PATH)/Makefile" ]; then \
		$(MAKE) -C $(SERVICE_PATH) build; \
	else \
		CGO_ENABLED=$(CGO_ENABLED) \
		$(GO) build -tags '$(ALL_TAGS)' \
			$(if $(filter true,$(ENABLE_BUILD_CACHE)),-x) \
			-ldflags '$(LD_FLAGS)' \
			-gcflags '$(GCFLAGS)' \
			-asmflags '$(ASMFLAGS)' \
			-o $(BIN_DIR)/$* \
			./$(SERVICE_PATH)/main.go; \
	fi
	@$(SUCCESS) "$* service was built successfully."

.PHONY: bake-%
bake-%: ## Prepare service (% = service name)
	@$(INFO) "Baking config for $* ..."
	@$(SUCCESS) "\n $* config baked successfully."

# =============================================================================
##@ 🧪 Testing & Quality
# =============================================================================
.PHONY: test
test: ## Run tests
	@$(INFO) "Running tests..."
	$(GO) test $(TEST_FLAGS) \
		-timeout $(TEST_TIMEOUT) \
		-run '$(TEST_PATTERN)' \
		$(if $(SKIP_PATTERN),-skip '$(SKIP_PATTERN)') \
		$(TEST_PACKAGES)

.PHONY: coverage
coverage: ## Run tests with coverage
	@$(INFO) "Running tests with coverage..."
	$(GO) test $(TEST_FLAGS) \
		-timeout $(TEST_TIMEOUT) \
		-coverprofile=$(COVERAGE_OUT) \
		$(TEST_PACKAGES)
	@if [ ! -d $(DOCS_DIR)/reports ]; then \
		mkdir -p $(DOCS_DIR)/reports; \
	fi
	$(GO) tool cover -html=$(COVERAGE_OUT) -o $(COVERAGE_HTML)
	@coverage=$$(go tool cover -func=$(COVERAGE_OUT) | grep total | awk '{print $$3}' | sed 's/%//'); \
	if [ "$${coverage%.*}" -lt "$(COVERAGE_THRESHOLD)" ]; then \
		$(NERROR) "Coverage $${coverage}%% is below threshold $(COVERAGE_THRESHOLD)%%"; \
		exit 1; \
	fi
	@$(SUCCESS) "Coverage report generated: $(COVERAGE_HTML)"

.PHONY: lint
lint: ## Run linters
	@$(INFO) "Running linters..."
	$(GOLANGCI_LINT) run
	@$(SUCCESS) "Lint complete!"

.PHONY: fmt
fmt: ## Format code
	@$(INFO) "Formatting code..."
	$(GO) fmt ./...
	$(GOFUMPT) -l -w .
	@$(SUCCESS) "Format complete!"

.PHONY: security
security: ## Run security checks
	@$(INFO) "Running security checks..."
	$(GOVULNCHECK) ./...
	@$(SUCCESS) "Security check complete!"

# =============================================================================
##@ 🧹 Cleanup & Maintenance
# =============================================================================
.PHONY: clean
clean: ## Clean build artifacts
	@$(TRASH) "Cleaning build artifacts..."
	rm -rf $(BIN_DIR) $(DIST_DIR)
	$(GO) clean -cache -testcache
	@$(SUCCESS) "Clean complete!"

.PHONY: deps
deps: ## Install dependencies
	@$(WORKING) "Installing dependencies..."
	$(GO) mod download
	@$(SUCCESS) "Dependencies installed!"

.PHONY: deps-tidy
deps-tidy: ## Update dependencies
	@$(WORKING) "Tidying dependencies..."
	$(GO) mod tidy
	@$(SUCCESS) "Dependencies tidied!"

.PHONY: deps-update
deps-update: ## Update dependencies
	@$(WORKING) "Updating dependencies..."
	$(GO) get -u ./...
	$(GO) mod tidy
	@$(SUCCESS) "Dependencies updated!"

.PHONY: deps-verify
deps-verify: ## Verify dependencies
	@$(INFO) "Verifying dependencies..."
	$(GO) mod verify
	@$(SUCCESS) "Dependencies verified!"

# =============================================================================
##@ 🔄 Development Workflow
# =============================================================================
.PHONY: dev-%
dev-%: deps bake-% generate ## Start development environment (% = service name)
	@$(INFO) "Starting $* development environment..."
	@$(ROCKET) "Running $*..."
	$(GO) run cmd/$*/main.go

.PHONY: run-%
run-%: bake-% build-% ## Run the application (% = service name)
	@if echo "$(SERVICES)" | grep -wq "cmd/$*"; then \
		$(ROCKET) "Running $*..."; \
		$(BIN_DIR)/$*; \
	else \
		$(ERROR) "'$*' is not a valid service."; \
		exit 1; \
	fi

.PHONY: generate
generate: ## Run code generation
	@$(WORKING) "Running code generation..."
	$(GO) generate ./...
	@$(SUCCESS) "Generation complete!"

# =============================================================================
##@ 🛠️ Tools & Utilities
# =============================================================================
.PHONY: tools
tools: ## Install all tools
	@$(INFO) "Preparing installations ..."
	@if [ ! -f "$(GOLANGCI_LINT)" ]; then \
		$(INFO) "Installing golangci-lint..."; \
		$(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; \
		$(SUCCESS) "golangci-lint was installed successfully"; \
	fi
	@if [ ! -f "$(GOFUMPT)" ]; then \
		$(INFO) "Installing gofumpt..."; \
		$(GO) install mvdan.cc/gofumpt@latest; \
		$(SUCCESS) "gofumpt was installed successfully"; \
	fi
	@if [ ! -f "$(GOVULNCHECK)" ]; then \
		$(INFO) "Installing govulncheck..."; \
		$(GO) install golang.org/x/vuln/cmd/govulncheck@latest; \
		$(SUCCESS) "govulncheck was installed successfully"; \
	fi
	@$(SUCCESS) "Tools installed!"

.PHONY: mock
mock: ## Generate mocks
	@$(WORKING) "Generating mocks..."
	$(MOCKERY)
	@$(SUCCESS) "Mocks generated!"

.PHONY: version
version: ## Display version information
	@printf "$(CYAN)Version:$(RESET)    %s \n" $(VERSION)
	@printf "$(CYAN)Commit:$(RESET)     %s \n" $(GIT_COMMIT)
	@printf "$(CYAN)Branch:$(RESET)     %s \n" $(GIT_BRANCH)
	@printf "$(CYAN)Built:$(RESET)      %s \n" $(BUILD_TIME)
	@printf "$(CYAN)Built by:$(RESET)   %s \n" $(BUILD_BY)
	@printf "$(CYAN)Go version:$(RESET) %s \n" "$(shell go version | sed 's/^go version //')"

# =============================================================================
##@ 📊 Reporting & Analytics
# =============================================================================
.PHONY: report
report: ## Generate project reports
	@$(INFO) "Generating project reports..."
	@mkdir -p $(DOCS_DIR)/reports
	@$(MAKE) coverage
	@$(MAKE) benchmark-report
	@$(MAKE) lint-report
	@$(MAKE) security-report
	@$(SUCCESS) "Reports generated in $(DOCS_DIR)/reports"

.PHONY: benchmark-report
benchmark-report:
	$(GO) test -bench=. -benchmem ./... > $(DOCS_DIR)/reports/benchmark.txt

.PHONY: lint-report
lint-report:
	$(GOLANGCI_LINT) run --out-format checkstyle > $(DOCS_DIR)/reports/lint-checkstyle.xml

.PHONY: security-report
security-report:
	$(GOVULNCHECK) -json ./... > $(DOCS_DIR)/reports/security.json

# =============================================================================
# 📁 Directory Creation
# =============================================================================
$(BIN_DIR) $(DIST_DIR) $(DOCS_DIR):
	mkdir -p $@

# =============================================================================
##@ 🔁 Self
# =============================================================================
self-update:
	@echo "Updating $(SELF_FILE)..."
	@curl -sSfL $(REPO_URL) -o $(SELF_FILE)
	@echo "Update complete."

# =============================================================================
##@ 💡 Help
# =============================================================================
.PHONY: help
help: ## Show this help message
	@printf "$(CYAN)$(BOLD)%s$(RESET) - %s \n" "$(PROJECT_NAME)" "$(DESCRIPTION)"
	@printf "$(WHITE)Maintained by %s$(RESET) \n \n" "$(MAINTAINER)"
	@printf "$(RED)Service list: $(RESET) %s \n\n" "$(SERVICES)"
	@printf "$(CYAN)$(BOLD)Available targets:$(RESET) \n"
	@awk 'BEGIN {FS = ":.*##"; printf ""} \
		/^[a-zA-Z_%-]+:.*?##/ { printf "  $(BLUE)* %-20s$(RESET) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(MAGENTA)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@printf "\n $(YELLOW)$(BOLD) ** %s ** $(RESET) \n" $(DISCLAIMER)


.DEFAULT_GOAL := help
