#!/bin/bash

# Server configuration variables
SERVER_NAME="yorserver.example.com"  # Set your server name here
SERVER_PORT="1195"            # Set your server port here

# MySQL database details
DB_NAME="asterisk"
TABLE_NAME="endpointman_mac_list"

# EasyRSA and OpenVPN configuration details
EASY_RSA_DIR="/etc/openvpn/easyrsa3"
CLIENT_DIR="/etc/openvpn/clients"
CLIENT_CONFIG_DIR="/etc/openvpn/ccd"
TFTPBOOT_DIR="/tftpboot"


# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to the Easy-RSA directory
cd $EASY_RSA_DIR || { echo "Failed to navigate to Easy-RSA directory"; exit 1; }

# Check if PKI is initialized
if [ ! -d "pki" ]; then
    echo "Warning: PKI is not initialized. Please run './easyrsa init-pki' first."
    exit 1
fi

# Check if CA exists
if [ ! -f "pki/ca.crt" ]; then
    echo "Warning: CA certificate does not exist. Please run './easyrsa build-ca' first."
    exit 1
fi

# Connect to MySQL and retrieve MAC addresses
MAC_ADDRESSES=$(mysql -D "$DB_NAME" -N -e "SELECT mac FROM $TABLE_NAME;")

# Loop through each MAC address
for MAC in $MAC_ADDRESSES; do
    CLIENT_NAME=$(echo "$MAC" | tr '[:upper:]' '[:lower:]')
    CLIENT_FILE="$CLIENT_DIR/$CLIENT_NAME.ovpn"
    CLIENT_CONFIG_FILE="$CLIENT_CONFIG_DIR/$CLIENT_NAME"    
    CLIENT_KEY_FILE="$EASY_RSA_DIR/pki/private/$CLIENT_NAME.key"
    CLIENT_CERT_FILE="$EASY_RSA_DIR/pki/issued/$CLIENT_NAME.crt"
    TAR_FILE="$TFTPBOOT_DIR/$CLIENT_NAME.tar"

    # Check if the client key and certificate exist
    if [ ! -f "$CLIENT_KEY_FILE" ] || [ ! -f "$CLIENT_CERT_FILE" ]; then
        echo "Generating keys and certificate for '$CLIENT_NAME'..."
        ./easyrsa build-client-full "$CLIENT_NAME" nopass
        cp -fr "$CLIENT_KEY_FILE" "$CLIENT_DIR/$CLIENT_NAME.key"
        cp -fr "$CLIENT_CERT_FILE" "$CLIENT_DIR/$CLIENT_NAME.crt"
    else
        echo "Client keys and certificate for '$CLIENT_NAME' already exist."
    fi

    # Check if the client configuration file exists, if not create it
    if [ ! -f "$CLIENT_CONFIG_FILE" ]; then
	touch "$CLIENT_CONFIG_FILE"
    fi
    
    # Check if the client file exists, if not create it
    if [ ! -f "$CLIENT_FILE" ]; then
echo "Creating client configuration for '$CLIENT_NAME'..."

# Read the static configuration from the separate file

cat "$SCRIPT_DIR/client_config_template.conf" > "$CLIENT_FILE"

# Append the inline certificates and keys
cat >> "$CLIENT_FILE" <<EOF
remote $SERVER_NAME $SERVER_PORT
<ca>
$(cat pki/ca.crt)
</ca>
<cert>
$(cat pki/issued/$CLIENT_NAME.crt)
</cert>
<key>
$(cat pki/private/$CLIENT_NAME.key)
</key>
EOF

echo "Client configuration for '$CLIENT_NAME' created at '$CLIENT_FILE'."

        echo "Client configuration for '$CLIENT_NAME' created at '$CLIENT_FILE'."
    else
        echo "Client configuration for '$CLIENT_NAME' already exists at '$CLIENT_FILE'."
    fi

    # Check if the tar file exists, if not create it from the config file
    if [ ! -f "$TAR_FILE" ]; then
        echo "Creating tar archive for '$CLIENT_NAME'..."
        rm /tmp/vpn.cnf
        cp "$CLIENT_FILE" /tmp/vpn.cnf
        tar -cvf "$TAR_FILE" -C /tmp vpn.cnf
        echo "Tar archive created at '$TFTPBOOT_DIR/$CLIENT_NAME.tar'."
    else
        echo "Tar archive for '$CLIENT_NAME' already exists at '$TAR_FILE'."
    fi

done

echo "All configurations processed."

