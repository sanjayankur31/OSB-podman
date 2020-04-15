#!/bin/bash

# Copyright 2019 Ankur Sinha
# Author: Ankur Sinha <sanjay DOT ankur AT gmail DOT com> 
# File : run_mysql.sh
# References:
#
# man podman-run
# https://hacklog.in/understand-podman-networking/
# https://www.redhat.com/sysadmin/container-networking-podman
# https://balagetech.com/convert-docker-compose-services-to-pods/


SELINUX_ACTIVE="$(getenforce)"
MYSQL_HOSTDIR="/mnt/Scratch/mysql"
CONTAINER_NAME="osb-mysql"

function check_selinux ()
{
    if [ "Enforcing" = "$SELINUX_ACTIVE" ]
    then
        echo "Please set SELINUX to Permissive before using this container."
        echo "$ sudo setenforce 0"
        echo "Exiting."
        exit 0
    else
        echo "SELINUX is in permissive mode. Proceeding."
    fi
}

function fetch_image ()
{
    podman pull sameersbn/mysql:latest

}

function run_container ()
{
    mkdir -pv "$MYSQL_HOSTDIR" && \
    podman run --name "$CONTAINER_NAME" --env 'DB_NAME=redmine,geppetto' \
    --env 'DB_USER=user_name' --env 'DB_PASS=password' \
    --volume '/mnt/Scratch/mysql:/var/lib/mysql' \
    --security-opt="label=disable" --publish "3306:3306" \
    --rm -d docker.io/sameersbn/mysql
}

function enter_interactive ()
{
    podman exec -it "$CONTAINER_NAME" /bin/bash
}

function try_mysql ()
{
    mysql -u user_name -h 0.0.0.0 -P 3306 -p
}

function usage()
{
    echo "$0 [-ri]"
    echo 
    echo "OPTIONS"
    echo
    echo "-r pull image and run container"
    echo "-i enter container interactively"
    echo "-m connect using mysql client"
}

# parse options
while getopts "rim" OPTION
do
    case $OPTION in
        r)
            check_selinux && fetch_image && run_container
            ;;
        i)
            enter_interactive
            ;;
        m)
            try_mysql
            ;;
        ?)
            echo "Nothing to do."
            usage
            exit 1
            ;;
    esac
done