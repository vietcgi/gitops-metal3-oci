#!/bin/bash
# Download Harvester v1.6.1 PXE boot files
# Run this on the bootstrapper server (108.181.38.67)

set -e

HARVESTER_VERSION="v1.6.1"
BASE_URL="https://releases.rancher.com/harvester/${HARVESTER_VERSION}"
DEST_DIR="/var/www/harvester"

echo "Downloading Harvester ${HARVESTER_VERSION} PXE boot files..."

# Create destination directory
sudo mkdir -p "${DEST_DIR}"

# Download required files
echo "Downloading kernel..."
sudo wget -O "${DEST_DIR}/harvester-${HARVESTER_VERSION}-vmlinuz-amd64" \
    "${BASE_URL}/harvester-${HARVESTER_VERSION}-vmlinuz-amd64"

echo "Downloading initrd..."
sudo wget -O "${DEST_DIR}/harvester-${HARVESTER_VERSION}-initrd-amd64" \
    "${BASE_URL}/harvester-${HARVESTER_VERSION}-initrd-amd64"

echo "Downloading rootfs squashfs..."
sudo wget -O "${DEST_DIR}/harvester-${HARVESTER_VERSION}-rootfs-amd64.squashfs" \
    "${BASE_URL}/harvester-${HARVESTER_VERSION}-rootfs-amd64.squashfs"

# Copy config and iPXE script
echo "Copying configuration files..."
sudo cp "$(dirname "$0")/config-create.yaml" "${DEST_DIR}/"
sudo cp "$(dirname "$0")/harvester.ipxe" "${DEST_DIR}/"

# Set permissions
sudo chown -R www-data:www-data "${DEST_DIR}"
sudo chmod -R 755 "${DEST_DIR}"

echo ""
echo "Files downloaded to ${DEST_DIR}:"
ls -lh "${DEST_DIR}/"

echo ""
echo "Add the following to nginx config to serve Harvester files on port 8081:"
echo ""
cat << 'NGINX'
server {
    listen 8081;
    server_name _;

    location /harvester/ {
        alias /var/www/harvester/;
        autoindex on;
    }
}
NGINX

echo ""
echo "To boot anvil into Harvester, chainload to:"
echo "  http://108.181.38.67:8081/harvester/harvester.ipxe"
