#!/bin/bash
#####################################################################################
###
###  Script: ose_user_maint.sh
###
###  Description: This script is used to add and delete ose_users.  It must be 
###               run from the "system:admin" account.
###
####################################################################################


RESP=N

while [ "$RESP" != "X" ] ; do
   clear
   echo "###################################################################################"
   echo "###  This script is used to add and delete users from the OpenShift environment."
   echo "###  It will prompt for (A)dd, (D)elete or e(X)it.  For adds it will require a"
   echo "###  a username, password, password confirmation, and a user label.  Deletes only"
   echo "###  require the username"
   echo "###################################################################################"
   echo 
   echo -n "Do you want to (A)dd, (D)elete, or e(X)it? "
   read RESP
   RESP=`echo $RESP | tr '[:lower:]' '[:upper:]'`

   if [ "$RESP" == "A" ] ; then
      echo -n "Enter Username: "
      read UNAME
      if [ "$RESP" != "" ] ; then
         echo -n "New password: "
         stty -echo
         read NPASSWD 
         echo
         echo -n "Re-type new password: "
         read VPASSWD
         echo
         stty echo
         if [ "$NPASSWD" != "$VPASSWD" ] ; then
            echo " ... Passwords do not match"
            sleep 3
         else
            RESP=Y
            while [[ "$RESP" != "A" && "$RESP" != "B" && "$RESP" != "D" && "$RESP" != "X" ]] ; do
               echo -n "Enter User Label (A)lpha, (B)eta, (D)efault, or e(X)it? "
               read RESP
               RESP=`echo $RESP | tr '[:lower:]' '[:upper:]'`
        
               if [ "$RESP" == "A" ] ; then
                  GROUP="Alpha Corp"
                  LABEL="alpha"
               elif [ "$RESP" == "B" ] ; then
                  GROUP="Beta Corp"
                  LABEL=beta
               elif [ "$RESP" != "X" ] ; then
                  echo " ... Illegal entry, valid entries are A, B, D, and X"
                  echo
               fi
            done

            if [ "$RESP" != "X" ] ; then
               ansible masters[0] -m shell -a "htpasswd -mb /etc/origin/master/htpasswd $UNAME $NPASSWD"
               oc adm groups add-users $GROUP $UNAME
               oc label user/$UNAME client=$LABEL
               echo -n "... Enter <return> to continue"
               read WAIT
            fi
         fi
      fi
   elif [ "$RESP" == "D" ] ; then
      echo -n "Enter Username: "
      read UNAME
      if [ "$RESP" != "" ] ; then
            ansible masters[0] -m shell -a "htpasswd -D /etc/origin/master/htpasswd $UNAME"

            GROUP=`oc get groups | grep brian | awk '{print $1}'`
            oc adm groups remove-users $GROUP $UNAME

            echo -n "... Enter <return> to continue"
            read WAIT
      fi
   elif [ "$RESP" == "X" ] ; then
      break
   else
      echo " ... Illegal entry, valid entries are A, D, and X"
     sleep 3
   fi
done
