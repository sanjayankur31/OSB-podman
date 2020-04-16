#!/bin/bash

# Copyright 2019 Ankur Sinha
# Author: Ankur Sinha <sanjay DOT ankur AT gmail DOT com>
# File : create_pod.sh
#

SELINUX_ACTIVE="$(getenforce)"

PODNAME="osb"
RECREATE_POD="no"

REDMINE_IMAGE_NAME="redmine"
REDMINE_CONTAINER_NAME="osb-redmine"
REDMINE_HOSTDIR="/mnt/Scratch/redmine"

MYSQL_CONTAINER_NAME="osb-mysql"
MYSQL_HOSTDIR="/mnt/Scratch/mysql"

GEPPETTO_IMAGE_NAME="geppetto"
GEPPETTO_CONTAINER_NAME="osb-geppetto"

function create_pod ()
{
    if [ "yes" = "$RECREATE_POD" ]
    then
        podman pod exists $PODNAME && podman pod rm -f $PODNAME
    fi

    # Otherwise try to create it if it doesn't exist anyway
    podman pod exists $PODNAME || podman pod create --name $PODNAME --hostname $PODNAME \
        --publish 10083:80 --publish 10084:10084 \
        --publish 3306:3306 --publish 8080:8080
}

function start_pod ()
{
    # don't error if this can't find a pod
    # starting a pod starts all the containers in it
    podman pod exists $PODNAME && podman pod start $PODNAME
}

function stop_pod ()
{
    # don't error if this can't find a pod
    podman pod exists $PODNAME && podman pod stop $PODNAME && podman pod rm $PODNAME
}

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

function fetch_mysql_image ()
{
    podman pull sameersbn/mysql:latest

}

function create_mysql_container ()
{
    podman container rm "$MYSQL_CONTAINER_NAME"
    mkdir -pv "$MYSQL_HOSTDIR" && \
        podman create --name "$MYSQL_CONTAINER_NAME" \
        --env 'DB_NAME=redmine,geppetto' \
        --env 'DB_USER=user_name' \
        --env 'DB_PASS=password' \
        --volume '/mnt/Scratch/mysql:/var/lib/mysql' \
        --security-opt="label=disable" --expose=3306 \
        --pod=$PODNAME \
        -d docker.io/sameersbn/mysql

}

function start_mysql_container ()
{
    podman start "$MYSQL_CONTAINER_NAME"

}

function enter_mysql_interactive ()
{
    podman exec -it "$MYSQL_CONTAINER_NAME" /bin/bash
}

function try_mysql ()
{
    mysql -uuser_name -h 0.0.0.0 -P 3306 -ppassword
}

function import_database ()
{
    mysql -uuser_name -ppassword -h 0.0.0.0 -P 3306 redmine < ~/Sync/2020-OSB/redmine.sql && \
    mysql -uuser_name -ppassword -h 0.0.0.0 -P 3306 geppetto < ~/Sync/2020-OSB/geppetto.sql
}

function build_redmine_image ()
{
    # Don't put the args of -f in quotes, it doesn't like it
    # Ports need to be published when the container is run, not when the image
    # is created
    # All environment variables also need to be set when the container is run,
    # not when the image is created. For image creation, we need build
    # arguments only.
    mkdir -pv "$REDMINE_HOSTDIR" && \
    podman build --tag "$REDMINE_IMAGE_NAME" \
        --build-arg="SERVER_IP=http://localhost:10083/" \
        --build-arg="GEPPETTO_IP=http://localhost:8080/" \
        --security-opt="label=disable" --userns=host \
        --force-rm=true \
        -f ~/Documents/02_Code/00_mine/2020-OSB/docker-redmine-osb/Dockerfile

}

function create_redmine_container ()
{
    podman container rm "$REDMINE_CONTAINER_NAME"
    mkdir -pv "$REDMINE_HOSTDIR" && \
        podman create --name "$REDMINE_CONTAINER_NAME" --env 'DB_NAME=redmine,geppetto' \
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
        --env 'NGINX_ENABLED=true' \
        --security-opt="label=disable" \
        --expose=10083 \
        --expose=80 \
        --userns=host \
        --pod=$PODNAME \
        --volume '/mnt/Scratch/redmine:/home/redmine/data' \
        --volume '/mnt/Scratch/myGitRepositories:/home/svnsvn/myGitRepositories' \
        "$REDMINE_IMAGE_NAME"
}

function start_redmine_container ()
{
    podman start "$REDMINE_CONTAINER_NAME"

}

function enter_redmine_interactive ()
{
    podman exec -it "$REDMINE_CONTAINER_NAME" /bin/bash
}

function build_geppetto_image ()
{
    podman build --tag "$GEPPETTO_IMAGE_NAME" \
        --build-arg="SERVER_IP=http://localhost:10083/" \
        --build-arg="GEPPETTO_IP=http://localhost:8080/" \
        --security-opt="label=disable" --userns=host \
        --force-rm=true \
        -f ~/Documents/02_Code/00_mine/2020-OSB/docker-osb/Dockerfile
}

function create_geppetto_container ()
{
    podman container rm "$GEPPETTO_CONTAINER_NAME"
    podman create --name "$GEPPETTO_CONTAINER_NAME" \
        --security-opt="label=disable" \
        --expose=8080 \
        --userns=host \
        --pod=$PODNAME \
        "$GEPPETTO_IMAGE_NAME"
}

function start_geppetto_container ()
{
    podman start "$GEPPETTO_CONTAINER_NAME"
}

function enter_geppetto_interactive ()
{
    podman exec -it "$GEPPETTO_CONTAINER_NAME" /bin/bash
}


function usage()
{
    echo "$0 [-csSbtimh]"
    echo
    echo "OPTIONS:"
    echo "-r destroy and recreate pod: required if ports have been updated"
    echo "-c [all|pod|redmine|geppetto|mysql] create pod and specified container"
    echo "-s [all|pod|redmine|geppetto|mysql] start pod and specified container"
    echo "-S stop the pod and all containers"
    echo "-b [all|redmine|geppetto] build specified image"
    echo "-t [redmine|geppetto|mysql] enter container interactively"
    echo "-i [yes] import database into mysql container: assumes that pod and mysql container are running"
    echo "-m connect to mysql database using mysql client"
    echo "-h print usage and exit"
    echo
}

if [ "$#" -lt 1 ]
then
    echo "Needs at least one option"
    usage
    exit 0
fi

# parse options
while getopts "r:c:s:Sb:t:i:mh" OPTION
do
    case $OPTION in
        r)
            RECREATE_POD="$OPTARG"
            ;;
        c)
            if [ "all" = "$OPTARG" ]
            then
                create_pod
                create_mysql_container
                create_geppetto_container && \
                create_redmine_container
            elif [ "pod" = "$OPTARG" ]
            then
                create_pod
            elif [ "redmine" = "$OPTARG" ]
            then
                create_pod
                create_mysql_container
                create_redmine_container
            elif [ "geppetto" = "$OPTARG" ]
            then
                create_pod && \
                create_geppetto_container
            elif [ "mysql" = "$OPTARG" ]
            then
                create_pod && \
                create_mysql_container
            fi
            exit 0
            ;;
        s)
            if [ "all" = "$OPTARG" ]
            then
                start_pod
            elif [ "pod" = "$OPTARG" ]
            then
                start_pod
            elif [ "redmine" = "$OPTARG" ]
            then
                start_pod
                start_mysql_container
                start_redmine_container
            elif [ "geppetto" = "$OPTARG" ]
            then
                start_pod && \
                start_geppetto_container
            elif [ "mysql" = "$OPTARG" ]
            then
                start_pod && \
                start_mysql_container
            fi
            exit 0
            ;;
        S)
            stop_pod
            exit 0
            ;;
        b)
            if [ "all" = "$OPTARG" ]
            then
                build_redmine_image
                build_geppetto_image
            elif [ "redmine" = "$OPTARG" ]
            then
                build_redmine_image
            elif [ "geppetto" = "$OPTARG" ]
            then
                build_geppetto_image
            fi
            exit 0
            ;;
        t)
            if [ "redmine" = "$OPTARG" ]
            then
                enter_redmine_interactive
            elif [ "geppetto" = "$OPTARG" ]
            then
                enter_geppetto_interactive
            elif [ "mysql" = "$OPTARG" ]
            then
                enter_mysql_interactive
            else
                echo "Unknown container: $OPTARG."
                exit 1
            fi
            exit 0
            ;;
        i)
            if [ "yes" = "$OPTARG" ]
            then
                import_database
            fi
            exit 0
            ;;
        m)
            try_mysql
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
