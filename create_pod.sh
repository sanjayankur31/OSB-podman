#!/bin/bash

# Copyright 2019 Ankur Sinha
# Author: Ankur Sinha <sanjay DOT ankur AT gmail DOT com> 
# File : create_pod.sh
#

PODNAME="osb"
REDMINE_CONTAINER_NAME="osb-redmine"
MYSQL_CONTAINER_NAME="osb-mysql"

function create_pod ()
{
    # don't error if this can't find a pod
    podman pod exists $PODNAME && podman pod rm -f $PODNAME
    podman pod create --name $PODNAME --hostname $PODNAME \
        --publish 10083:80 --publish 3306:3306 --publish 8080:8080
}

function usage()
{
    echo "$0 [-rimp]"
    echo 
    echo "OPTIONS"
    echo
    echo "-r run the pod"
}

# parse options
while getopts "r" OPTION
do
    case $OPTION in
        r)
            create_pod
            exit 0
            ;;
        h)
            usage
            exit 0
            ;;
        ?)
            echo "Nothing to do."
            usage
            exit 1
            ;;
    esac
done
