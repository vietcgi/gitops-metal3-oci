# iPXE Boot Media

This directory contains scripts to build bootable USB and ISO images for bare metal provisioning with Tinkerbell.

## Quick Start

1. **Set your Tinkerbell URL:**
   ```bash
   export TINKERBELL_URL=https://tinkerbell.yourdomain.com
   ```

2. **Build the boot media:**
   ```bash
   # Build both USB and ISO
   make all TINKERBELL_URL=$TINKERBELL_URL

   # Or just USB
   make usb TINKERBELL_URL=$TINKERBELL_URL

   # Or just ISO
   make iso TINKERBELL_URL=$TINKERBELL_URL
   ```

3. **Output files:**
   - `output/metal-foundry.usb` - Bootable USB image
   - `output/metal-foundry.iso` - Bootable ISO image
   - `output/metal-foundry.efi` - EFI binary (for UEFI boot)

## Usage

### For Physical Access Machines (USB Boot)

1. Write the USB image to a flash drive:
   ```bash
   # Linux
   sudo dd if=output/metal-foundry.usb of=/dev/sdX bs=4M status=progress

   # macOS
   sudo dd if=output/metal-foundry.usb of=/dev/rdiskN bs=4m
   ```

2. Boot the server from the USB drive

3. iPXE will automatically:
   - Configure network via DHCP
   - Contact your Tinkerbell server
   - Download the provisioning workflow
   - Install the OS

### For Remote Machines (IPMI Virtual Media)

1. Access the server's BMC/IPMI/iLO/iDRAC web interface

2. Mount the ISO via Virtual Media:
   - Navigate to Virtual Media or Remote Console
   - Mount `metal-foundry.iso` as a virtual CD/DVD

3. Set boot order to boot from virtual CD first

4. Power cycle the server

5. The provisioning will proceed automatically

## How It Works

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Bare Metal     │     │   iPXE Boot     │     │   Tinkerbell    │
│  Server         │────▶│   (USB/ISO)     │────▶│   Server        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │ 1. Boot from USB/ISO  │                       │
        │◀──────────────────────│                       │
        │                       │                       │
        │ 2. DHCP (get IP)      │                       │
        │──────────────────────▶│                       │
        │                       │                       │
        │ 3. Chain to Tinkerbell│                       │
        │                       │──────────────────────▶│
        │                       │                       │
        │ 4. Receive workflow   │                       │
        │◀──────────────────────────────────────────────│
        │                       │                       │
        │ 5. Execute workflow   │                       │
        │   - Partition disk    │                       │
        │   - Install OS        │                       │
        │   - Configure K3s     │                       │
        │                       │                       │
        │ 6. Reboot into OS     │                       │
        │──────────────────────▶│                       │
```

## Prerequisites

For building (one of):
- Docker (recommended - no local dependencies)
- OR: gcc, binutils, make, perl, xorriso, mtools

For using:
- A Tinkerbell server accessible from the bare metal network
- Hardware registered in Tinkerbell
- A workflow created for the hardware

## Troubleshooting

### "Could not reach Tinkerbell server"

1. **Check network connectivity:**
   - Ensure the bare metal machine can reach the internet
   - Check firewall rules

2. **Verify Tinkerbell URL:**
   - The URL should be HTTPS
   - Test with curl: `curl -v $TINKERBELL_URL`

3. **Check hardware registration:**
   - The MAC address must be registered in Tinkerbell
   - Verify with: `kubectl get hardware -n tink-system`

### "No workflow found"

1. **Verify hardware is registered:**
   ```bash
   kubectl get hardware -n tink-system
   ```

2. **Create a workflow for the hardware:**
   ```bash
   kubectl apply -f tinkerbell/workflows/your-workflow.yaml
   ```

### UEFI vs BIOS

- The USB image works with both UEFI and BIOS systems
- The ISO image works with both UEFI and BIOS systems
- The EFI binary is for direct UEFI booting

## Customization

Edit `ipxe-script.ipxe` to customize the boot behavior:
- Add custom menu options
- Configure static IP
- Add debug output
- Chain to different endpoints
