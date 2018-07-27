#!/bin/bash
#################################################################################
###
###  Script: git_upload.sh
###
###  Written By: Mark E Turlik  on  July 27, 2018
###
###  Decsription:  This script uploads all changes to the github repository.
###
#################################################################################
clear
echo "###############################################################"
echo "### This script uploads all changes within the repository"
echo "### \"mark-e-turlik-accenture-com/master/OpenShiftHomework\""
echo "###############################################################"
echo

while [[ "$RESP" != "Y" && "$RESP" != "N" ]] ; do
   echo -n "Perform the upload (y/n) "
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

cd ..
git push -f
