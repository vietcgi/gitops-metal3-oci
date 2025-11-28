# iPXE Boot Media Builder
#
# Creates bootable USB and ISO images for bare metal provisioning.
# These boot images chainload to your Tinkerbell server.
#
# Usage:
#   make usb          - Create bootable USB image
#   make iso          - Create bootable ISO image
#   make all          - Create both USB and ISO
#   make clean        - Remove build artifacts
#
# Requirements:
#   - Docker (for building in container)
#   - OR: gcc, binutils, make, xorriso (for native build)
#

# Configuration
TINKERBELL_URL ?= https://tinkerbell.example.com
IPXE_REPO := https://github.com/ipxe/ipxe.git
IPXE_VERSION := v1.21.1
BUILD_DIR := build
OUTPUT_DIR := output

.PHONY: all usb iso clean docker-build

all: usb iso

# Build using Docker (recommended - no local dependencies)
docker-build:
	@echo "Building iPXE boot media using Docker..."
	docker run --rm -v $(PWD):/work -w /work alpine:latest sh -c '\
		apk add --no-cache git gcc musl-dev make binutils perl xorriso mtools && \
		make native-build TINKERBELL_URL=$(TINKERBELL_URL)'

# Native build (requires local toolchain)
native-build: $(BUILD_DIR)/ipxe $(OUTPUT_DIR)
	@echo "Generating iPXE script..."
	@cat ipxe-script.ipxe | sed "s|TINKERBELL_URL|$(TINKERBELL_URL)|g" > $(BUILD_DIR)/ipxe/src/metal-foundry.ipxe

	@echo "Building iPXE for USB..."
	cd $(BUILD_DIR)/ipxe/src && make bin/ipxe.usb EMBED=metal-foundry.ipxe
	cp $(BUILD_DIR)/ipxe/src/bin/ipxe.usb $(OUTPUT_DIR)/metal-foundry.usb

	@echo "Building iPXE for ISO..."
	cd $(BUILD_DIR)/ipxe/src && make bin/ipxe.iso EMBED=metal-foundry.ipxe
	cp $(BUILD_DIR)/ipxe/src/bin/ipxe.iso $(OUTPUT_DIR)/metal-foundry.iso

	@echo "Building iPXE for EFI..."
	cd $(BUILD_DIR)/ipxe/src && make bin-x86_64-efi/ipxe.efi EMBED=metal-foundry.ipxe
	cp $(BUILD_DIR)/ipxe/src/bin-x86_64-efi/ipxe.efi $(OUTPUT_DIR)/metal-foundry.efi

	@echo ""
	@echo "Build complete! Output files:"
	@ls -la $(OUTPUT_DIR)/

$(BUILD_DIR)/ipxe:
	@mkdir -p $(BUILD_DIR)
	git clone --depth 1 --branch $(IPXE_VERSION) $(IPXE_REPO) $(BUILD_DIR)/ipxe

$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)

# Quick build using Docker
usb:
	@echo "Building USB image..."
	@make docker-build
	@echo ""
	@echo "USB image ready: $(OUTPUT_DIR)/metal-foundry.usb"
	@echo ""
	@echo "Write to USB drive with:"
	@echo "  Linux:   sudo dd if=$(OUTPUT_DIR)/metal-foundry.usb of=/dev/sdX bs=4M status=progress"
	@echo "  macOS:   sudo dd if=$(OUTPUT_DIR)/metal-foundry.usb of=/dev/rdiskN bs=4m"
	@echo ""

iso:
	@echo "Building ISO image..."
	@make docker-build
	@echo ""
	@echo "ISO image ready: $(OUTPUT_DIR)/metal-foundry.iso"
	@echo ""
	@echo "Use with IPMI virtual media or burn to CD/DVD."
	@echo ""

clean:
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR)

# Help
help:
	@echo "iPXE Boot Media Builder"
	@echo ""
	@echo "Usage:"
	@echo "  make usb TINKERBELL_URL=https://your-tinkerbell.com"
	@echo "  make iso TINKERBELL_URL=https://your-tinkerbell.com"
	@echo "  make all TINKERBELL_URL=https://your-tinkerbell.com"
	@echo ""
	@echo "The TINKERBELL_URL should be your Tinkerbell server's public HTTPS endpoint."
