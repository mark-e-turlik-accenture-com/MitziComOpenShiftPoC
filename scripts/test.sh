#!/bin/sh

echo -n "Enter passwd: "
stty -echo
read NPASSWD
echo

echo -n "Verify passwd: "
read VPASSWD
echo

stty echo
