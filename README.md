Just a simple script, that creates TAR files containing VPN configuration complatible with Yealink phones.
Intended to be used with OSS Endpoint Manager module for FreePBX.
The script will list every provisioned mac address in endpointman_mac_list table and create OpenVPN client config for each. 
Resulting TAR files will be placed in your /tftpboot directory. 
You can provision your vpn connection in $mac.cfg file of your provisioning template like this:
network.vpn_enable = 1
openvpn.url = https://yourserver.example.com/{$mac}.tar
