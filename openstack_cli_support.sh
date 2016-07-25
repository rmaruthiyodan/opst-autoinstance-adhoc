#!/bin/bash

export OS_AUTH_URL=http://172.26.132.10:5000/v3
export CINDER_ENDPOINT_TYPE=internalURL
export NOVA_ENDPOINT_TYPE=internalURL
export OS_ENDPOINT_TYPE=internalURL
export OS_NO_CACHE=1

# For openstackclient
export OS_IDENTITY_API_VERSION=3
export OS_AUTH_VERSION=3

export OS_USERNAME="oktalogin"
export OS_TENANT_NAME="support-lab"
export OS_PROJECT_NAME="support-lab"
export OS_USER_DOMAIN_NAME=HORTON
export OS_PROJECT_DOMAIN_NAME=HORTON

echo "Please enter your OpenStack Password: "
read -sr OS_PASSWORD_INPUT
export OS_PASSWORD=$OS_PASSWORD_INPUT

if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
