#!/bin/bash
#####################################################################################
###
###  Script: create_5gb_pv_yaml.sh
###
###  Description: This script create 25 yaml files used to create 5GB PVs.
###
####################################################################################
export GUID=`hostname|awk -F. '{print $2}'`

export volsize="10Gi"
mkdir /root/pvs
for volume in pv{26..50} ; do
cat << EOF > /root/pvs/${volume}
{
  "apiVersion": "v1",
  "kind": "PersistentVolume",
  "metadata": {
    "name": "${volume}"
  },
  "spec": {
    "capacity": {
        "storage": "${volsize}"
    },
    "accessModes": [ "ReadWriteOnce" ],
    "nfs": {
        "path": "/srv/nfs/user-vols/${volume}",
        "server": "support1.${GUID}.internal"
    },
    "persistentVolumeReclaimPolicy": "Recycle"
  }
}
EOF
echo "Created def file for ${volume}";
done;
