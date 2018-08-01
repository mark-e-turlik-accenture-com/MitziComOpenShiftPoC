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

#------------------------------------
#---  Colored text escape sequences
#------------------------------------
red="\033[1;31m"
reset=$(tput sgr0)

clear
echo -e "#############################################################################"
echo -e "###"
echo -e "###  This script creates the entire OpenShift environment for the Mitzcom"
echo -e "###  Corporation Proof of Concept engagement.  It is ${red}highly recommended${reset}"
echo -e "###  ${red}that the user run this script from within a TMUX terminal session ${reset}to"
echo -e "###  allow for the session to be reattached if disconnected."
echo -e "###"
echo -e "#############################################################################"
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

echo
echo "#####################################################"
echo "### Save a copy of the original Ansible hosts file"
echo "#####################################################"
echo "cp /etc/ansible/hosts /etc/ansible/hosts.ORIG"
cp /etc/ansible/hosts /etc/ansible/hosts.ORIG

#-------------------------------------------------------------------
#--- Copy the htpasswd to /tmp for use by /etc/ansisble/hosts file
#-------------------------------------------------------------------
cp ../inventory/htpasswd.openshift /tmp

echo
echo "##############################################################"
echo "### Add GUID environment variable to all host .bashrc files"
echo "##############################################################"
ansible localhost,all -m shell -a 'export GUID=`hostname | cut -d"." -f2`; echo "export GUID=$GUID" >> $HOME/.bashrc'

echo
echo "#############################################################"
echo "### Replace the entered GUID within the ODE hosts template"
echo "#############################################################"
cp ../inventory/hosts.homework /etc/ansible/hosts
sed -i "s/GUID/$GUID/g" /etc/ansible/hosts

echo
echo "##################################################################"
echo "###  Run the ansible prerequisite and deploy-cluster play-books"
echo "##################################################################"
ansible-playbook -f 20 /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -f 20 /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml

#-----------------------------------
#--- Remove the /tmp/htpasswd file
#-----------------------------------
rm -f /tmp/htpasswd.openshift

echo
echo "############################################"
echo "### Verify Docker is running on all nodes"
echo "############################################"
ansible nodes -m shell -a"systemctl status docker | grep Active"

echo "###################################################################################"
echo "### Copy the .kube directory to allow system:admin access from the bastion host"
echo "###################################################################################"
ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"

echo "###############################################"
echo "### Give the admin user cluster-admin access"
echo "###############################################"
oc adm policy add-cluster-role-to-user cluster-admin admin

echo "####################################################"
echo "### Verify that the environment is functioning ..."
echo "####################################################"
oc get nodes --show-labels
oc get pod --all-namespaces -o wide

echo
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
sleep 3
oc logs -f bc/nodejs-mongo-persistent -n smoke-test

echo
echo "#########################################################################################"
echo "### Create a default projects template with limits and Network Policies set to ISOLATED"
echo "#########################################################################################"
oc create -f ../files/default-project-template.yaml -n default
ansible-playbook ../inventory/set_default_projects.yaml

echo "####################################################################################"
echo "### Create Dev, Test and Prod projects. Deploy Jenkins app to manage deployment"
echo "### Enable Jenkins Service account to manage resources in Test and Prod projects."
echo "####################################################################################"
oc new-project pipeline-dev  --display-name="Develop Project"
oc new-project pipeline-test --display-name="Test Project"
oc new-project pipeline-prod --display-name="Production Project"

oc project pipeline-dev
oc new-app jenkins-persistent -p ENABLE_OAUTH=false -e JENKINS_PASSWORD=openshiftpipelines -n pipeline-dev

oc policy add-role-to-user edit system:serviceaccount:pipeline-dev:jenkins -n pipeline-test
oc policy add-role-to-user edit system:serviceaccount:pipeline-dev:jenkins -n pipeline-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:pipeline-test -n pipeline-dev
oc policy add-role-to-group system:image-puller system:serviceaccounts:pipeline-prod -n pipeline-dev

echo
echo "##############################################################################"
echo "### Create the \"Cat of the Day (cotd2)\" app in the \"pipeline-dev\" project"
echo "##############################################################################"
oc project pipeline-dev
oc new-app php~https://github.com/StefanoPicozzi/cotd2 -n pipeline-dev
sleep 3
#oc logs -f build/cotd2-1 -n pipeline-dev
oc logs -f bc/cotd -n pipeline-dev

echo "#############################################"
echo "### Tag the cotd2 image the \"pipeline-dev\""
echo "#############################################"
oc tag cotd2:latest cotd2:testready -n pipeline-dev
oc tag cotd2:testready cotd2:prodready -n pipeline-dev

echo
echo "###################################"
echo "### Deploy the cotd2 app in TEST"
echo "###################################"
oc new-app pipeline-dev/cotd2:testready --name=cotd2 -n pipeline-test
sleep 3
oc logs -f bc/cotd -n pipeline-test

echo
echo "###################################"
echo "### Deploy the cotd2 app in PROD"
echo "###################################"
oc new-app pipeline-dev/cotd2:prodready --name=cotd2 -n pipeline-prod
sleep 3
oc logs -f bc/cotd -n pipeline-prod

echo
echo "########################################"
echo "### Expose the Dev, Test and Prod APPs"
echo "########################################"
oc expose service cotd2 -n pipeline-dev
oc expose service cotd2 -n pipeline-test
oc expose service cotd2 -n pipeline-prod

echo
echo "##########################################"
echo "### Create the pipeline-dev build config"
echo "##########################################"
oc create -f ../inventory/pipeline_build.yaml

echo
echo "##################################################"
echo "### Set up autoscaling for the cotd2 app in PROD"
echo "##################################################"
oc autoscale dc/cotd2 --min 1 --max 5 --cpu-percent=80 -n pipeline-prod
oc get hpa/cotd2 -n pipeline-prod

oc create -f ../inventory/pipeline_build.yaml

echo
echo "###########################################################"
echo "### Create and assign users to the Aplha and Bete groups"
echo "###########################################################"
oc adm groups new Alpha-Corp amy andrew
oc adm groups new Beta-Corp betty brian

echo
echo "###############################################################"
echo "### Create and assign policies to the Alpha and Beta projects"
echo "###############################################################"
oc adm new-project alpha-project --display-name="Alpha Project" --description="Alpha Project for alpha resources" --node-selector="client=alpha"
oc adm new-project beta-project --display-name="Beta Project" --description="Beta Project for beta resources" --node-selector="client=beta"
oc adm policy add-role-to-group admin Alpha-Corp -n alpha-project
oc adm policy add-role-to-group admin Beta-Corp  -n beta-project

oc new-app nodejs-mongo-persistent -n alpha-project
sleep 3
oc logs -f bc/nodejs-mongo-persistent -n alpha-project

oc new-app nodejs-mongo-persistent -n beta-project
sleep 3
oc logs -f bc/nodejs-mongo-persistent -n beta-project
