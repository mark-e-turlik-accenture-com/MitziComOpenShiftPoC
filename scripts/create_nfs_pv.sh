#!/bin/bash
#####################################################################################
###
###  Script: create_nfs_pv.sh
###
###  Description: This script is run on the nfs server to create the 50 PVs to be
###               utilized for persistent storage by the OpenShift components.
###               it is executed from the "../inventory/create_nfs_pv.yaml" file.
###
#####################################################################################
mkdir -p /srv/nfs/user-vols/pv{1..200}

for pvnum in {1..50} ; do
   echo "/srv/nfs/user-vols/pv${pvnum} *(rw,root_squash)" >> /etc/exports.d/openshift-uservols.exports
   chown -R nfsnobody.nfsnobody  /srv/nfs
   chmod -R 777 /srv/nfs
done

systemctl restart nfs-server
