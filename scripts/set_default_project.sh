#!/bin/bash
#####################################################################################
###
###  Script: set_default_project.sh
###
###  Description: This script is run on the master1 server to set the "projectRequestTemplate"
###               varaible in the "master-config.yaml" file.  It subsequently restarts the 
###               master controller.
###
#####################################################################################
sed -i 's#.*projectRequestTemplate.*#  projectRequestTemplate: "default/project-request"#g' /etc/origin/master/master-config.yaml
systemctl restart atomic-openshift-master-api atomic-openshift-master-controllers
