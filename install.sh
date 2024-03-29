#!/bin/bash
# Author: https://github.com/jinouchi
# This script installs Wazuh Server on Debian systems.

if [[ $(whoami) != "root" ]]
then
  echo "This script must be run as root. Exiting."
  exit
  else echo "You are root! Continuing..."
fi
  
# Variables:
if [[ "$DEB_VER" == "" ]]; then DEB_VER=$(cat /etc/issue | sed 's/Debian GNU\/Linux \(.*\) \\n \\l/\1/'); fi
if [[ "$DEB_VER" -gt 6 ]] 2>/dev/null
then
  echo "Debian version detected successfully. Detected version: $DEB_VER"
else
  echo "Debian version could not be detected from /etc/issue. Exiting."
  echo "If you know which version of debian you are using, export the variable: export DEB_VER=9"
  exit
fi

# Install curl
apt-get install curl apt-transport-https gnupg2 -y

# Add Repos:
# Install Wazuh GPG key and repository:
if [[ $(ls /etc/apt/sources.list.d/wazuh.list > /dev/null 2>&1 ; echo $?) -ne 0 ]]
then 
  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
  echo "deb https://packages.wazuh.com/3.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
fi

# Add the Elastic repository and its GPG key:
if [[ $(ls /etc/apt/sources.list.d/elastic-7.x.list > /dev/null 2>&1 ; echo $?) -ne 0 ]]
then
  curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
fi

# Refresh apt 
apt-get update


# Wazuh
# Install pre-requisites
apt-get install lsb-release -y

# Install Wazuh server
apt-get install wazuh-manager -y

# Install NodeJS
# If Debian version is 7.x, use Node.JS version 6. Otherwise, use version 8.
if [[ $DEB_VER -eq 7 ]]
then
  curl -sL https://deb.nodesource.com/setup_6.x | bash -
else
  curl -sL https://deb.nodesource.com/setup_8.x | bash -
fi

apt-get install nodejs -y


# Install the Wazuh API. It will update NodeJS if it is required:
apt-get install wazuh-api -y


# Filebeat
# Install Filebeat:
apt-get install filebeat=7.5.0

# Download the Filebeat config file from the Wazuh repository. This is pre-configured to forward Wazuh alerts to Elasticsearch:
curl -so /etc/filebeat/filebeat.yml https://raw.githubusercontent.com/wazuh/wazuh/v3.10.2/extensions/filebeat/7.x/filebeat.yml

# Download the alerts template for Elasticsearch:
curl -so /etc/filebeat/wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/v3.10.2/extensions/elasticsearch/7.x/wazuh-template.json

# Download the Wazuh module for Filebeat:
curl -s https://packages.wazuh.com/3.x/filebeat/wazuh-filebeat-0.1.tar.gz | tar -xvz -C /usr/share/filebeat/module

# Enable and start the Filebeat service:
# For Systemd:
systemctl daemon-reload
systemctl enable filebeat.service
systemctl start filebeat.service


# Install Elastic Stack
# Install the Elasticsearch package:
apt-get install elasticsearch=7.5.0


# Load the Filebeat template.
filebeat setup --index-management -E setup.template.json.enabled=false


# Kibana
# Install Kibana
apt-get install kibana=7.5.0

# Install the Wazuh app plugin for Kibana:
su - kibana -c '/usr/share/kibana/bin/kibana-plugin install file:///path/wazuhapp-3.10.2_7.5.0.zip'

# Enable and start the Kibana service:
systemctl daemon-reload
systemctl enable kibana.service
systemctl start kibana.service

# Cleanup
# Disable Wazuh repository in order to prevent accidental upgrades (recommended):
sed -i "s/^deb/#deb/" /etc/apt/sources.list.d/wazuh.list

# Disable the Elasticsearch updates:
sed -i "s/^deb/#deb/" /etc/apt/sources.list.d/elastic-7.x.list

# Refresh apt
apt-get update


# Final Steps:
echo
echo "==========Final Steps: Filebeat=========="
echo 'Edit the file /etc/filebeat/filebeat.yml and replace YOUR_ELASTIC_SERVER_IP with the IP address or the hostname of the Elasticsearch server. For example:'
echo "output.elasticsearch.hosts: ['http://YOUR_ELASTIC_SERVER_IP:9200']"
echo "Restart FileBeat: systemctl start filebeat.service"
echo
echo "==========Final Steps: Elasticsearch=========="
echo 'Elasticsearch will only listen on the loopback interface (localhost) by default. Configure Elasticsearch to listen to a non-loopback address by editing the file /etc/elasticsearch/elasticsearch.yml and uncommenting the setting network.host. Change the value to the IP you want to bind it to:'
echo 'network.host: <elasticsearch_ip>'
echo 'Further configuration will be necessary after changing the network.host option. Add or edit (if commented) the following lines in the file /etc/elasticsearch/elasticsearch.yml:'
echo 'node.name: <node_name>'
echo 'cluster.initial_master_nodes: ["<node_name>"]'
# Start Daemon
echo
echo 'After configuration is complete, start the daemon:'
echo 'systemctl daemon-reload'
echo 'systemctl enable elasticsearch.service'
echo 'systemctl start elasticsearch.service'
echo
echo "==========Final Steps: Kibana=========="
echo 'Kibana will only listen on the loopback interface (localhost) by default, which means that it can be only accessed from the same machine. To access Kibana from the outside make it listen on its network IP by editing the file /etc/kibana/kibana.yml, uncomment the setting server.host, and change the value to:'
echo 'server.host: "<kibana_ip>"'
echo 'Configure the URLs of the Elasticsearch instances to use for all your queries. By editing the file /etc/kibana/kibana.yml:'
echo 'elasticsearch.hosts: ["http://<elasticsearch_ip>:9200"]'
