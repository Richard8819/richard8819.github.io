#!/bin/bash
echo "=============================================="
echo "       Squid-Proxy Bootstrap-version:0.2"     "
echo "=============================================="

#Def pkg name
package_name='squid'
#Def squid user
SQUID_USER='squidadm'
#Def log file and path
LOG_FILE="/var/log/squid_install.log"
echo > $LOG_FILE

# Function to log messages
log_message()  {
  echo "$(date '+%Y-%m-%d %H:%M:%S' ) - $1" | tee -a "$LOG_FILE"
}
  log_message "Starting Squid Proxy installation/configuration..."

# Function to check scb-webservices.repo exist or not in yum.repo.d repository

if [[ -s "/etc/yum.repos.d/scb-webservices.repo" ]]; then
  log_message "scb-webservices.repo already exists. Skipping repository setup."
else
  log_message "scb-webservices.repo not found. Setting up repository..."
  
  sudo tee /etc/yum.repos.d/scb-webservices.repo > /dev/null <<EOL
[scb-webservices]
name=SCB Webservices Repository
baseurl=https://artifactory.global.standardchartered.com/artifactory/rpm-webeng-production_local/webrpm/RHEL9
enabled=1
gpgcheck=1
gpgkey=https://artifactory.global.standardchartered.com/artifactory/rpm-webeng-production_local/webrpm/RHEL9/SCB-WEBENG-RPM-KEY
EOL


# Update package repository
  sudo yum update -y > dev/null
mkdir -p /etc/squid/src-workload-configs
touch /etc/squid/src-workload-configs/dummy.conf
ip= ifconfig ens192 | grep inet | awk '{print $2}'
echo "acl src_42030 src $ip" > /etc/squid/src-workload-configs/dummy.conf
echo "acl src_42030 src 127.0.0.1" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl url_regex_42030_https_443_2 url_regex -i ^http://www.dlptest.com/" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl url_regex_42030_http_80_1 url_regex -i ^http://www.dlptest.com/" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl dstdomain_42030_https_443_2 dstdomain www.dlptest.com" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl port_42030_https_443_2 port 443" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl method_42030_2 method CONNECT" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl method_42030_2 method GET" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl method_42030_2 method POST" >> /etc/squid/src-workload-configs/dummy.conf
echo "acl method_42030_2 method HEAD" >> /etc/squid/src-workload-configs/dummy.conf
echo "http_access allow src_42030 url_regex_42030_https_443_2 port_42030_https_443_2 method_42030_2" >> /etc/squid/src-workload-configs/dummy.conf
echo "http_access allow src_42030 dstdomain_42030_https_443_2 port_42030_https_443_2 method_42030_2" >> /etc/squid/src-workload-configs/dummy.conf
echo "http_access allow src_42030 url_regex_42030_http_80_1 port_42030_http_80_1 method_42030_2" >> /etc/squid/src-workload-configs/dummy.conf

# Function to check if the user exisits

if id "$SQUID_USER" &>/dev/null; then
  log_message "User $SQUID_USER already exists. Proceeding with Squid installation."
else
  log_message "User $SQUID_USER does not exist. Please create the user before proceeding with Squid installation."
  exit 1
fi

# check if the package is already installed or not
if rpm -q $package_name &>/dev/null; then
  log_message "Squid is already installed. Skipping installation."
else
  log_message "Squid is not installed. Installing Squid..."
  sudo yum install -y $package_name # Use 'dnf' instead of 'yum' for RHEL 8 and later
  fi

# Backup the original squid.conf file
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Ensure Squid configuration directory exists with correct permissions
for dir in /var/spool/squid /var/log/squid /run/squid /etc/squid/ssl_ca_cert /etc/squid/conf.d/; do
  if [ ! -d "$dir" ]; then
    sudo mkdir -p "$dir"
    log_message "Created directory: $dir"
  fi
  sudo chown -R $SQUID_USER:$SQUID_USER "$dir"
  sudo chmod -R 775 "$dir"
done

# Ensure Squid config is readable and writable by the Squid user
if [[ ! -f "/etc/squid/squid.conf" ]]; then
  log_message "Squid configuration file not found. Creating a new one."
  sudo touch /etc/squid/squid.conf
fi
sudo chown -R $SQUID_USER:$SQUID_USER /etc/squid
sudo chmod -R 775 /etc/squid
sudo chmod 775 /etc/squid/squid.conf
# Ensure Squid config has the correct PID file path
if ! grep -q "pid_filename /run/squid/squid.pid" /etc/squid/squid.conf; then
  log message "Adding the PID file configuration to squid.conf"
  echo "pid_filename /run/squid/squid.pid" | sudo tee -a /etc/squid/squid.conf > /dev/null
fi

# Create a new Squid configuration file
sudo tee /etc/squid/squid.conf > /dev/null <<EOL
# This file serves as the main configuration for Squid Proxy Server. It includes various components from different 
# directories to modularize the configuration and enhance maintainability and it is strongly adviced to keep the original configuration file intact and use this file for any modifications or additions to the Squid configuration.
include "/etc/squid/conf.d/*"
EOL

# Ensure base.conf exists or not in conf.d directory

if [[ -s "/etc/squid/conf.d/base.conf" ]]; then
  log_message "base.conf already exists in conf.d directory. Skipping base configuration setup."
else
  log_message "base.conf not found in conf.d directory. Setting up base configuration..."
  
  sudo tee /etc/squid/conf.d/base.conf > /dev/null <<EOL

  # This is the base configuration file for Squid Proxy Server. It contains the fundamental settings and directives that are essential for the operation of the Squid Proxy Server. This file is included in the main squid.conf file and serves as the foundation for the Squid configuration. It is recommended to keep this file intact and use it as a reference for any modifications or additions to the Squid configuration.

  # squid normally listens on port 3128

http_port 8080 ssl-bump tls-default-ca=off generate-host-certificates=on dynamic_cert_mem_cache_size=16MB cert=/etc/squid/ssl_ca_cert/sproxy-ca-cert-key.pem tls-dh=/etc/squid/ssl_ca_cert/dhparam.pem
http_port 8081 ssl-bump tls-default-ca=off generate-host-certificates=on dynamic_cert_mem_cache_size=16MB cert=/etc/squid/ssl_ca_cert/sproxy-ca-cert-key.pem tls-dh=/etc/squid/ssl_ca_cert/dhparam.pem
http_port 8082 ssl-bump tls-default-ca=off generate-host-certificates=on dynamic_cert_mem_cache_size=16MB cert=/etc/squid/ssl_ca_cert/sproxy-ca-cert-key.pem tls-dh=/etc/squid/ssl_ca_cert/dhparam.pem
http_port 8083 ssl-bump tls-default-ca=off generate-host-certificates=on dynamic_cert_mem_cache_size=16MB cert=/etc/squid/ssl_ca_cert/sproxy-ca-cert-key.pem tls-dh=/etc/squid/ssl_ca_cert/dhparam.pem

# if you are using nginx as a reverse proxy then it should use the below lines

http_port 8080 require-proxy-header ssl-bump tls-default-ca=off generate-host-certificates=on dynamic_cert_mem_cache_size=16MB cert=/etc/squid/ssl_ca_cert/sproxy-ca-cert-key.pem tls-dh=/etc/squid/ssl_ca_cert/dhparam.pem
proxy_protocol_access allow all

dns_nameservers 1.1.1.1 4.2.2.2 9.9.9.9

workers 6

# Example rule allowing access from local networks.
# Adapt to list your (internal) IP networks from where browsing should be allowed
acl localnet src 0.0.0.1-0.255.255.255 # RFC1122 "this" network LAN
acl localnet src 10.0.0.0/8       # RFC1918 possible internal network
acl localnet src 100.64.0.0/10    # RFC6598 shared address space
acl localnet src 169.254.0.0/16   # RFC3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12    # RFC1918 local private network (LAN)
acl localnet src 192.168.0.0/16   # RFC1918 local private network (LAN)
acl localnet src fc00::/7       # RFC 4193 unique local address
acl localnet src fe80::/10     # RFC 4291 link-local (directly plugged) machines

acl SSL_ports port 443
acl safe_ports port 1025-65535          # unregistered ports
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 1-65535   # reserved ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http

acl CONNECT method CONNECT

# Deny "X-Forwarded-For" "X-Cache" and "X-Cache-Lookup" headers. Also includes other security best practices
reply_header_access X-Cache deny all
reply_header_access X-Cache-Lookup deny all
follow_x_forwarded_for allow localhost
follow_x_forwarded_for deny all
request_header_access X-Forwarded-For deny all
forwarded_for delete
#Via off

# HTTP upgrade
http_upgrade_request_protocols OTHER allow all

# Recommended minimum Access Permission configuration:
#
# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
#http_access deny CONNECT !SSL_ports
http_access deny CONNECT !Safe_ports

# Only allow cachemgr access from localhost
http_access allow localhost manager
http_access deny manager

# We strongly recommend the following be uncommented to protect innocent web applications 
# running on the proxy server who think the only one who can access services on "localhost" is a local user.
# http_access deny to_localhost

# INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS
# Example rule allowing access from local networks.
# Adapt localnet in the ACL section to list your (internal) IP networks from where browsing should be allowed
http_access allow localnet

# User ACL files are included in below statement
include /etc/squid/src-workload-configs/*.conf

# And finally deny all other access to this proxy
http_access deny all

#ICAP config
#icap_enable on
#icap_service_failure_limit -1
#icap_preview_enable on
#icap_preview_size 1024
#icap_persistent_connections on
#adaptation_send_client_ip on
#adaptation_send_username on
#icap_service_metascan_service_req reqmod_precache icap://10.0.11:1344/squidclamav bypass=0
#icap_service_metascan_service_resp respmod_precache icap://10.0.11:1344/squidclamav bypass=0
#icap_service_metascan_service_req reqmod_precache icap://10.0.9:1344/srv_echo bypass=0
#icap_service_metascan_service_resp respmod_precache icap://10.0.9:1344/srv_echo bypass=0
#icap_service_metascan_service_req reqmod_precache icap://10.0.5:1344/OMSScanReq-AV bypass=0
#icap_service_metascan_service_resp respmod_precache icap://10.0.5:1344/OMSScanResp-AV bypass=0

#ICAP ACL best practices
#acl exclude_method method CONNECT
#acl exclude_content_type rep_mime_type application/ocsp-response
#acl exclude_content_type rep_mime_type text/html

#adaptation_access metascan_resp deny exclude_contenttype
#adaptation_access metascan_req deny exclude_method
#adaptation_access metascan_req allow all
#adaptation_access metascan_resp allow all

# Always allow download if missing intermediate  HTTPS certificate for badly configured sites
acl fetched_certificate transaction_initiator certificate-fetching
cache allow fetched_certificate
http_access allow fetched_certificate

# pseudo authentication (IP to username mapping) by user labelling

# external_acl_type label_auth children-max=20 children-startup=5 children-idle=10 %SRC %>eui /etc/squid/auth/label_auth.py
--conf=/etc/squid/auth/auth_labels.json

# User labelling, this means label_auth will provide IP address -> user name mapping 
# acl label_auth_acl external label_auth
# http_access alllow label_auth_acl

# Disable IPv6 support if not needed
# acl to_ipv6 dst ipv6
# http_access deny to_ipv6

# will not cache anything
# acl all-src src 0.0.0.0/0
 cache deny all-src

# Uncomment and adjust the following lines to add a disk cache directory.
#cache_dir ufs /var/spool/squid 100 16 256

cache_mem 4 GB

# Here we are mounting dedicated partition on squid logging directory /var/spool/squid.
# Pre-requisite is to have such a partition with size, say 50 GB created already.
# mount -t xfs /dev/mapper/SquidLog-VarSpoolSquid /var/spool/squid

# Leave coredumps in the first cache directory
coredump_dir /var/spool/squid

# Add any of your own refresh_pattern entries above these.
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern -i (/cgi-bin/|\?) 0       0%      0
refresh_pattern .               0       20%     4320

# Log formats and rotation
# logformat custom_log %{%Y-%m-%d %H:%M:%S}tl %>a:%p %[un %Ss/%03>Hs:%Sh "%rm %ru HTTP/%rv" %mt %>Hs %<st %tr %<a %pt %<tt %st
"%ssl::bump_mode" "%ssl::>sni" "%ssl::<cert_error" "%ssl::>negotiated_version" "%ssl::<negotiated_version"
"ssl::>negotiated_cipher" "%ssl::<negotiated_cipher" "%{User-Agent}>h" "%{Referer}>h" %adapt::sum_trs %adapt::<last_h

logformat splunk_squid %ts.%03tu logformat=splunk_squid duration=%tr src_ip=%>a src_port=%>p dest_ip=%<a dest_port=%<p user_ident="%[ui" user="%[un" local_time=[%tl] http_method=%rm request_method_from_client=%<rm request_method_to_server=%rm
url="%ru" http_reference="%{Referer}>h" http_user_agent="%{User-Agent}>h" status=%>Hs vendor_action=%Ss dest_status=%Sh
total_time_millseconds=%<tt http_content_type="%mt" bytes=%st bytes_in=%>st bytes_out=%<st sni="
ssl_decrypted="%ssl::bump_mode" ssl_server_cipher="%ssl::<negotiated_version" ssl_client_cipher="%ssl::>negotiated_cipher"
ssl_cert_error="%ssl::<cert_error" http_referer="%{Referer}>h" icap=%adapt::sum_trs icap_sum=%adapt::<last_h

access_log /var/log/squid/access_splunk.log splunk_squid

# access_log syslog:local4.info splunk_squid
# access_log /var/log/squid/access.log custom_log
# logformat icap_squid %ts.%03tu %6icap::tr %icap::ru %icap::rm %>A %icap::to/%03icap::Hs %icap::<st %icap::rm %icap::ru %un
-/%icap::<A -
#icap_log /var/log/squid/icap_access.log icap_squid

# debug_options 28,9
# debug_options ALL,1 93,7

EOL
fi

sudo chown -R "$SQUID_USER":"$SQUID_USER" /etc/squid/conf.d/base.conf
sudo chmod -R 775 /etc/squid/conf.d/base.conf
sudo chmod 775 /etc/squid/conf.d/base.conf

# Ensure ssl.conf exists or not in conf.d directory

if [[ -s "/etc/squid/conf.d/ssl.conf" ]]; then
  log_message "ssl.conf already exists in conf.d directory. Skipping SSL configuration setup."
else
  log_message "ssl.conf not found in conf.d directory. Setting up SSL configuration..."
  
  sudo tee /etc/squid/conf.d/ssl.conf > /dev/null <<EOL

# SSL certgen configuration
sslcrtd_program /usr/lib64/squid/security_file_certgen -s /var/spool/squid/ssl_db -M 4MB

# Best practices
tls_outgoing_options NO_SSLv3
tls_outgoing_options cipher=HIGH:MEDIUM:!R4:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS

# SSL global bypass for domains (FQDNs and Wildcards)
acl ssl_exclude_domain ssl::server_name www.xyz.com
acl ssl_exclude_domains ssl::server_name .def.com

# SSL global bypass for IP/Subnets
acl ssl_exclude_ips dst 8.8.8.8
acl ssl_exclude_ips dst 5.5.5.0/24

# SSL global bypass for servers/workloads IP/Subnets
acl ssl_exclude_useraddr src 10.40.0.10
acl ssl_exclude_useraddr src 10..25.0.0/16

# Global ignore SSL certificate errors by destination server domain name or IP address
acl ssl_error_domain dstdomain abc.com
acl ssl_error_ip dst 2.2.2.2
acl ssl_error_ip dst 3.3.3.3/32

sslproxy_cert_error allow ssl_error_domain
sslproxy_cert_error allow ssl_error_ip
sslproxy_cert_error allow all

# Splice exceptions
ssl_bump splice ssl_exclude_ips
ssl_bump splice ssl_exclude_domains
ssl_bump splice ssl_exclude_useraddr

# Bump all
acl step1 at_step SslBump1
ssl_bump peek step1
ssl_bump bump all
ssl_bump splice all
# always_direct allow all
# ssl_bump client-first all

EOL
fi
sudo chown -R "$SQUID_USER":"$SQUID_USER" /etc/squid/conf.d/ssl.conf
sudo chmod -R 775 /etc/squid/conf.d/ssl.conf
sudo chmod 775 /etc/squid/conf.d/ssl.conf

# Add ca cert and key for SSL bumping (Make sure its pem format)
# mkdir /etc/squid/ssl_ca_cert

# Ensure sproxy-ca-cert-key.pem exists or not in ssl_ca_cert directory

certpath="/etc/squid/ssl_ca_cert"
certkey="$certpath/sproxy-ca-cert-key.pem"
if [[ -s "$certkey" ]]; then
  log_message "Certificate key already exists at $certkey. Skipping certificate generation."
else
  log_message "Certificate key not found at $certkey. Generating self-signed certificate and key..."
  
  sudo tee "$certkey" > /dev/null <<EOL
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAzjLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+u
XGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQy
qjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh
5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqa2m1wID
AQABAoIBACVYpM9sY
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKC2VhLJjzPMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJDQTEP
MA0GA1UEBwwGQmVya2VsZXkxFjAUBgNVBAoMDVN0YW5kYXJkIENoYXJ0ZTAeFw0yNDA2MjkwODQ4MTVaFw0zNDA2MjcwODQ4MTVaMEUxCzAJBgNVBAYTAlVTMQswCQYDV
QQIDAJDQTEPMA0GA1UEBwwGQmVya2VsZXkxFjAUBgNVBAoMDVN0YW5kYXJkIENoYXJ0ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK1qLh7ZtqLl7+uXGQ
yqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjL
h5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqa2m1wIDAQABo1AwTjAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU9Wv3rM
9pUeBzD6iYl3aI3e9sUwHwYDVR0jBBgwFoAU9Wv3rM9pUeBzD6iYl3aI3e9sUwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAjLh7ZtqLl7+uXGQyqjL
h5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQy
qjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqjLh5H8ZtqLh7ZtqLl7+uXGQyqa2m1wIDAQAB
-----END CERTIFICATE-----
EOL
fi

sudo chown -R "$SQUID_USER":"$SQUID_USER" "$certkey"
sudo chmod -R 775 "$certkey"
sudo chmod 775 "$certkey"

# Ensure DH file exists or not in ssl_ca_cert directory

DH="$certpath/dhparam.pem"
if [[ -s "$DH" ]]; then
  log_message "DH parameters file already exists at $DH. Skipping DH parameters generation."
else  
  log_message "DH parameters file not found at $DH. Generating DH parameters..."
  sudo openssl dhparam -outform PEM -out /etc/squid/ssl_ca_cert/dhparam.pem
fi
sudo chown -R "$SQUID_USER":"$SQUID_USER" $certpath/dhparam.pem
sudo chmod -R 775 $certpath/dhparam.pem
sudo chmod 775 $certpath/dhparam.pem

# initiating SSL DB
ssldb=/var/spool/squid/ssl_db
if [ -d "$ssldb" ]; then
  log_message "SSL DB directory already exists at $ssldb. Skipping SSL DB initialization."
else
  log_message "SSL DB directory not found at $ssldb. Initializing SSL DB..."
  sudo /usr/lib64/squid/security_file_certgen -c -s /var/spool/squid/ssl_db -M 4MB
fi
sudo chown -R "$SQUID_USER":"$SQUID_USER" /var/spool/squid/ssl_db
sudo chmod -R 775 /var/spool/squid/ssl_db
sudo chmod 775 /var/spool/squid/ssl_db

# Test squid configuration
sudo squid -k parse

# Initiate the cache
# sudo squid -z

# Modify Squid configuration to use the non-root user
# echo "Updating. Squid Configuration..."
# sudo sed -i "s/^cache_effective_user.*/cache_effective_user $SQUID_USER/"" /etc/squid/squid.conf
# sudo sed -i "s/^cache_effective_group.*/cache_effective_group $SQUID_USER/"" /etc/squid/squid.conf

# Ensure Squid uses the correct PID file path
log_message "Setting the Squid PID file path in the configuration"
echo "pid_filename /run/squid/squid.pid" | sudo tee -a /etc/squid/squid.conf > /dev/null

# Modify systemd service file to run squid as non-root user
# Modify Squid systemd service file (if not already modified)
if [[ ! -f "/etc/systemd/system/squid.service" ]]; then
  log_message "Squid systemd service file not found. Creating a new one..."
  sudo tee /etc/systemd/system/squid.service > /dev/null <<EOL
[Unit]
Description=Squid Web Proxy Server
After=network.target
-
[Service]
User=$SQUID_USER
Group=$SQUID_USER
ExecStartPre=/bin/mkdir -p /run/squid
ExecStartPre=/bin/chown $SQUID_USER:$SQUID_USER /run/squid
ExecStartPre=/bin.chmod 775 /run/squid
ExecStartPre=/usr/sbin/squid -z
ExecStart=/usr/sbin/squid -f /etc/squid/squid.conf --force-foreground
ExecReload=/usr/sbin/squid -k reconfigure
Execstop=/usr/sbin/squid -k shutdown
restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOL
fi

# Reload systemd to apply changes and start Squid service
log_message "Reloading systemd daemon and starting Squid service..."
sudo systemctl daemon-reload
sudo systemctl enable squid
sudo systemctl restart squid

# Verify Squid PID file creation
if [[ -f "run/squid/squid.pid" ]]; then
  log_message "Squid started successfully and PID file created, with PID: $(cat /run/squid/squid.pid)"
else
  log_message "Error: Squid PID file not found. Please check the service status and logs for more details."
  sudo journalctl -u squid --no-pager | tail 50
fi

# Check Squid status
log_message "Checking Squid service status..."
systemctl status squid --no-pager
sleep 15
use_proxy=yes
export http_proxy=http://$ip:8080
export https_proxy=http://$ip:8080
wget -a "$LOG_FILE" --delete-after --no-check-certificate https://dlptest.com
top -bHnl | head -15 >> "$LOG_FILE"

echo " " >> $LOG_FILE

echo "localhost 8080
localhost 8081
localhost 8082
localhost 8083" | (
  TCP_TIMEOUT=3
while read host port ;
do
(CURPID=$BASHID;
(sleep $tcp_TIMEOUT && kill -9 $CURPID) &
exec 3<>/dev/tcp/$host/$port) 2>/dev/null
case $? in
0)
echo "Port $port on $host is open" >> "$LOG_FILE";;
1)
echo "Port $port on $host is closed" >> "$LOG_FILE";;
143) # killed by SIGTERM
echo "$host $port timedout >> $LOG_FILE";;
esac
done
) 2>/dev/null #avoid bash message "Terminated..."

if [ -e /etc/cron.daily/logarchival.sh ]; then
  echo "Log files archival script already exists. Skipping log archival setup."
else
  touch /etc/cron.daily/logarchival.sh
  mkdir -p /var/spool/squid/archive
  eho "mv /var/log/squid/*.gz /var/spool/squid/archive/" > /etc/cron.daily/logarchival.sh
  chmod +x /etc/cron.daily/logshift.sh
  chmod +x /etc/cron.daily/logarchival.sh
  echo "0 23 * * * /etc/cron.daily/logshift.sh" >/etc/cron.daily/logarchival.sh
  fi
  log_message "Log archival setup completed using user $SQUID_USER."
  
