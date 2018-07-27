#!/bin/bash
#################################################################################
###
###  Script: install_ose.sh
###
###  Written By: Mark E Turlik  on  July 27, 2018
###
###  Decsription:  This script prompts the user for the Cluster GUID to be
###                used to host the OpenShift environment.  It subsequently
###                performs the entire OpenShift installation for the MITZICOM
###                deployment.
###
#################################################################################
clear
echo "################################################################"
echo "###"
echo "###  This script will create the OpenShift environment for ...
echo "###"
echo "#################################################################"
echo
echo -n "Enter the Cluster GUID: "
read GUID

cd /root
wget http://ipa.shared.example.opentlc.com/ipa/config/ca.crt -O /root/ipa-ca.crt

cp /root/hosts.homework /etc/ansible/hosts
sed -i 's/GUID/$GUID/g' /etc/ansible/hosts
