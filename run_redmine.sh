#!/bin/bash

# Copyright 2019 Ankur Sinha
# Author: Ankur Sinha <sanjay DOT ankur AT gmail DOT com>
# File :  run_redmine.sh

IMAGE_NAME="redmine"
REDMINE_HOSTDIR="/mnt/Scratch/redmine"
CONTAINER_NAME="osb-redmine"
PODNAME="osb"

function build_image ()
{
    # Don't put the args of -f in quotes, it doesn't like it
    # Ports need to be published when the container is run, not when the image
    # is created
    # All environment variables also need to be set when the container is run,
    # not when the image is created. For image creation, we need build
    # arguments only.
    mkdir -pv "$REDMINE_HOSTDIR" && \
    podman build --tag "$IMAGE_NAME" \
        --build-arg="SERVER_IP=http://localhost:10083/" \
        --build-arg="GEPPETTO_IP=http://localhost:8080/" \
        --security-opt="label=disable" --userns=host \
        --force-rm=true \
        -f ~/Documents/02_Code/00_mine/2020-OSB/docker-redmine-osb/Dockerfile

}

function run_container ()
{
    mkdir -pv "$REDMINE_HOSTDIR" && \
        podman run --name "$CONTAINER_NAME" --env 'DB_NAME=redmine,geppetto' \
        --env 'TZ=Asia/Kolkata' \
        --env 'DB_ADAPTER=mysql2' \
        --env 'DB_HOST=osb' \
        --env 'DB_PORT=3306' \
        --env 'DB_USER=user_name' \
        --env 'DB_PASS=password' \
        --env 'DB_NAME=redmine' \
        --env 'REDMINE_PORT=10083' \
        --env 'REDMINE_HTTPS=false' \
        --env 'REDMINE_RELATIVE_URL_ROOT=' \
        --env 'REDMINE_SECRET_TOKEN=' \
        --env 'REDMINE_SUDO_MODE_ENABLED=false' \
        --env 'REDMINE_SUDO_MODE_TIMEOUT=15' \
        --env 'REDMINE_CONCURRENT_UPLOADS=2' \
        --env 'REDMINE_BACKUP_SCHEDULE=' \
        --env 'REDMINE_BACKUP_EXPIRY=' \
        --env 'REDMINE_BACKUP_TIME=' \
        --env 'SMTP_ENABLED=true' \
        --env 'SMTP_METHOD=sendmail' \
        --env 'SMTP_DOMAIN=www.example.com' \
        --env 'SMTP_HOST=smtp.gmail.com' \
        --env 'SMTP_PORT=587' \
        --env 'SMTP_USER=mailer@example.com' \
        --env 'SMTP_PASS=password' \
        --env 'SMTP_STARTTLS=true' \
        --env 'SMTP_AUTHENTICATION=:login' \
        --env 'IMAP_ENABLED=false' \
        --env 'IMAP_HOST=imap.gmail.com' \
        --env 'IMAP_PORT=993' \
        --env 'IMAP_USER=mailer@example.com' \
        --env 'IMAP_PASS=password' \
        --env 'IMAP_SSL=true' \
        --env 'IMAP_INTERVAL=30' \
        --security-opt="label=disable" \
        --expose=10083 \
        --expose=80 \
        --userns=host \
        --pod=$PODNAME \
        --volume '/mnt/Scratch/redmine:/home/redmine/data' \
        --volume '/mnt/Scratch/myGitRepositories:/home/svnsvn/myGitRepositories' \
        --rm "$IMAGE_NAME"
}


function enter_interactive ()
{
    podman exec -it "$CONTAINER_NAME" /bin/bash
}


function usage()
{
    echo "$0 [-rib]"
    echo
    echo "OPTIONS"
    echo
    echo "-r run container"
    echo "-i enter container interactively"
    echo "-b build image"
}

# parse options
while getopts "ribh" OPTION
do
    case $OPTION in
        r)
            run_container
            exit 0
            ;;
        i)
            enter_interactive
            exit 0
            ;;
        b)
            build_image
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
