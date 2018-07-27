#!/bin/bash
#################################################################################
###
###  Script: uninstall_ose.sh
###
###  Written By: Mark E Turlik  on  July 27, 2018
###
###  Decsription:  This script replaces the origin /etc/ansible/hosts and then
###                performs an uninstall of OpenShift.
###
#################################################################################
clear
echo "###############################################################"
echo "### OpenShift uninstall script.  To be run in case of error."
echo "###############################################################"
echo

while [[ "$RESP" != "Y" && "$RESP" != "N" ]] ; do
   echo -n "Do you want you uninstall the current OpenShift cluster (y/n) "
   read RESP
   RESP=`echo $RESP | tr '[:lower:]' '[:upper:]'`
   if [ "$RESP" == "Y" ] ; then
      break
   elif [ "$RESP" == "N" ] ; then
      exit
   else
      echo "  ... invald entry"
   fi
done

cp /etc/ansible/hosts.ORIG /etc/ansible/hosts
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/adhoc/uninstall.yml
ansible nodes -a "rm -rf /etc/origin"
ansible nfs -a "rm -rf /srv/nfs/*"
