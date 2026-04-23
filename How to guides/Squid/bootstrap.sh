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
