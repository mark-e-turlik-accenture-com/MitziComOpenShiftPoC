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
echo "#############################################################################"
echo "###"
echo "###  This script creates the entire OpenShift environment for the Mitzcom"
echo "###  Corporation Proof of Concept engagement.  It is highly recommended"
echo "###  that the user run this script from within a TMUX terminal session to"
echo "###  allow for the session to be reattached if disconnected."
echo "###"
echo "############################################################################"
echo

#----------------------------------------------------
#---  Only run the script if you are the root user
#----------------------------------------------------
if [ `whoami` != "root" ] ; then
   echo "You MUST run this script as the \"root\" user"
   echo " ... existing"
   exit
fi

#-----------------------------------------
#--- Prompt for the GUID of the Cluster
#-----------------------------------------
echo -n "Enter the Cluster GUID: "
read GUID

echo "#####################################################"
echo "### Save a copy of the original Ansible hosts file"
echo "#####################################################"
cp /etc/ansible/hosts /etc/ansible/hosts.ORIG

#-------------------------------------------------------------------
#--- Copy the htpasswd to /tmp for use by /etc/ansisble/hosts file
#-------------------------------------------------------------------
cp ../inventory/htpasswd.openshift /tmp

echo "##############################################################"
echo "### Add GUID environment variable to all host .bashrc files"
echo "##############################################################"
ansible localhost,all -m shell -a 'export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc'

echo "#############################################################"
echo "### Replace the entered GUID within the ODE hosts template"
echo "#############################################################"
cp ../inventory/hosts.homework /etc/ansible/hosts
sed -i "s/GUID/$GUID/g" /etc/ansible/hosts

echo "##################################################################"
echo "###  Run the ansible prerequisite and deploy-cluster play-books"
echo "##################################################################"
ansible-playbook -f 20 /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -f 20 /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml

#-----------------------------------
#--- Remove the /tmp/htpasswd file
#-----------------------------------
rm -f /tmp/htpasswd.openshift

echo "############################################"
echo "### Verify Docker is running on all nodes"
echo "############################################"
ansible nodes -m shell -a"systemctl status docker | grep Active"

echo "###################################################################################"
echo "### Copy the .kube directory to allow system:admin access from the bastion host"
echo "###################################################################################"
ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"

echo "####################################################"
echo "### Verify that the environment is functioning ..."
echo "####################################################"
oc get nodes --show-labels
oc get pod --all-namespaces -o wide

echo "############################"
echo "### Synchronize the groups"
echo "############################"
ansible-playbook ../inventory/executeGroupSync.yaml

echo "#############################################"
echo "### Create 10Gi and 5Gi persistent volumes"
echo "#############################################"
ansible-playbook ../inventory/create_nfs_pv.yaml
./create_5gb_pv_yaml.sh
./create_10gb_pv_yaml.sh
cat /root/pvs/* | oc create -f -
ansible nodes -m shell -a "docker pull registry.access.redhat.com/openshift3/ose-recycler:latest"
ansible nodes -m shell -a "docker tag registry.access.redhat.com/openshift3/ose-recycler:latest \
                           registry.access.redhat.com/openshift3/ose-recycler:v3.9.30"

echo "#######################################################################"
echo "### As a Smoke Test create and deploy the \"nodejs-mongo-persistent\""
echo "#######################################################################"
oc new-project smoke-test
oc new-app nodejs-mongo-persistent -n smoke-test
oc logs -f build/nodejs-mongo-persistent-1 -n smoke-test

echo "####################################################################################"
echo "### Create Dev, Test and Prod projects. Deploy Jenkins app to manage deployment"
echo "### Enable Jenkins Service account to manage resources in Test and Prod projects."
echo "####################################################################################"
oc new-project pipeline-${GUID}-dev  --display-name="Develop Project"
oc new-project pipeline-${GUID}-test --display-name="Test Project"
oc new-project pipeline-${GUID}-prod --display-name="Production Project"

oc project pipeline-${GUID}-dev
oc new-app jenkins-persistent -p ENABLE_OAUTH=false -e JENKINS_PASSWORD=openshiftpipelines -n pipeline-${GUID}-dev

oc policy add-role-to-user edit system:serviceaccount:pipeline-${GUID}-dev:jenkins -n pipeline-${GUID}-test
oc policy add-role-to-user edit system:serviceaccount:pipeline-${GUID}-dev:jenkins -n pipeline-${GUID}-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:pipeline-${GUID}-test -n pipeline-${GUID}-dev
oc policy add-role-to-group system:image-puller system:serviceaccounts:pipeline-${GUID}-prod -n pipeline-${GUID}-dev

echo "###############################################################"
echo "### Create the \"pipeline-${GUID}-dev\" project and cotd2 app"
echo "###############################################################"
oc project pipeline-${GUID}-dev
oc new-app php~https://github.com/StefanoPicozzi/cotd2 -n pipeline-${GUID}-dev
oc logs -f build/cotd2-1 -n pipeline-${GUID}-dev

echo "##################################################"
echo "### Tag the \"pipeline-${GUID}-dev]\" cotd2 app"
echo "##################################################"
oc tag cotd2:latest cotd2:testready -n pipeline-${GUID}-dev
oc tag cotd2:testready cotd2:prodready -n pipeline-${GUID}-dev

echo "######################################################"
echo "### Create the Test project and associated cotd2 app"
echo "######################################################"
oc new-app pipeline-${GUID}-dev/cotd2:testready --name=cotd2 -n pipeline-${GUID}-test
oc logs -f build/cotd2-1 -n pipeline-${GUID}-test

echo "######################################################"
echo "### Create the Prod project and associated cotd2 app"
echo "######################################################"
oc new-app pipeline-${GUID}-dev/cotd2:testready --name=cotd2 -n pipeline-${GUID}-prod
oc logs -f build/cotd2-1 -n pipeline-${GUID}-prod
###oc autoscale --min 1 --max 5 --cpu-percent=80
###oc get hpa/hello-openshift -n test-hpa

echo "########################################"
echo "### Expose the Dev, Test and Prod APPs"
echo "########################################"
oc expose service cotd2 -n pipeline-${GUID}-dev
oc expose service cotd2 -n pipeline-${GUID}-test
oc expose service cotd2 -n pipeline-${GUID}-prod

oc create -f ../inventory/pipeline_build.yaml

echo "#############################"
echo "### Add labels to the users"
echo "#############################"
oc label user/amy    client=alpha
oc label user/andrew client=alpha
oc label user/betty  client=beta
oc label user/brian  client=beta
