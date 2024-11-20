#!/bin/sh

# start_slim_v0.6.2.sh destroys the current running webserver to replace it with a new one. /!\ All the files previously uploaded and the
# results of analysis will be detroyed during the process.
# This script will kill, if exists, any other running SLIM container. After that a new container will be created
# As docker requires sudo permissions, the alternative is to use podman. The option -p will run the script with podman instead of docker

Help()
{
    # Display Help
    echo "start_slim_v0.6.2.sh destroys the current running webserver to replace it with a new one. "
    echo "/!\ All the files previously uploaded and the results of analysis will be detroyed during the process."
    echo
    echo "Syntax: start_slim_v0.6.2.sh [-h] [-p] [-P] [port]"
    echo "options:"
    echo "-h --help     Print this Help."
    echo ""
    echo "-d --docker   Use docker instead of podman"
    echo ""
    echo "-P --port     <numeric:numeric> Specify the port that has to be opened for the container. 8080:80 by default"
    echo ""
}

while getopts hdP: flag
do
    case "${flag}" in
        h) Help
        exit;;
        d) podman=false;;
        P) port="${OPTARG}";;
        \?) echo "usage: bash start_slim_v0.6.2.sh [-h|p|P]"
        # \?) echo "usage: bash start_slim_v0.6.2.sh [-h|P]"
        exit;;
    esac
done


# check if podman has been enabled in the arguments, if not set to true
if [ -z "${podman}" ]; then
    echo 'Running with podman'
    podman=true
else
    echo 'Running with docker'
fi

# Check if the user has set a new port and see if the argument follows the syntax
if [ -z "${port}" ]; then
    echo 'Port 8080:80 by default'
    port='8080:80'
else
    if [[ ${port} == *[:]* ]]; then
        echo "Using port ${port}"
    else
        echo "Error: port option must follow the syntax: <numeric:numeric>"
    fi
    
fi

# the main program starts here

if ${podman}; then
    # check if a container called slim is running
    isRunning=$( podman ps | grep slim | wc -l )
    if [ "${isRunning}" -eq "1" ]; then
        echo "slim is running"
        echo "Do you want to kill it ? [y/N]"
        read answer
        
        if [ "$answer" != "y" ]; then
            # if user do not want to kill the running container then exit
            exit 0
        fi
        
        dockerId=$( podman ps | grep slim | cut -c1-12 )
        echo "Killing the current docker"
        podman stop ${dockerId}
    else
        echo "slim is not running"
    fi
    
    echo "Rebuild the docker image"
    # the following commands returned errors when no container or image was found. Now changed to a try/catch loop.
    echo 'remove those containers that are paused exited or created'
    podman ps --filter status=paused --filter status=exited --filter status=created -aq | xargs podman rm -v 2> /dev/null # in podman ps --filter status there is no dead option so I turn it to paused
    
    echo 'remove those unused images'
    podman images  -f "dangling=true" -q | xargs podman rmi -f 2> /dev/null
    
    # build slim container using the dockerfile in this repository
    podman build -t slim .
    # docker rmi -f $(docker images -f "dangling=true" -q)
    
    echo "Restart the podman"
    podman run -p ${port} -d slim
else
    # check if a container called slim is running
    isRunning=$( docker ps | grep slim | wc -l )
    if [ "${isRunning}" -eq "1" ]; then
        echo "slim is running"
        echo "Do you want to kill it ? [y/N]"
        read answer
        
        if [ "${answer}" != "y" ]; then
            # if user do not want to kill the running container then exit
            exit 0
        fi
        
        dockerId=$( docker ps | grep slim | cut -c1-12 )
        echo "Killing the current docker"
        docker stop ${dockerId}
    else
        echo "slim is not running"
    fi
    
    echo "Rebuild the docker image"
    # remove those containers that are paused exited or created
    docker ps --filter status=dead --filter status=exited --filter status=created -aq | xargs docker rm -v 2> /dev/null
    # remove those unused images
    docker images  -f "dangling=true" -q | xargs docker rmi -f 2> /dev/null
    # build slim container using the dockerfile in this repository
    docker build -t slim .
    # docker rmi -f $(docker images -f "dangling=true" -q)
    
    echo "Restart the docker"
    docker run -p ${port} -d slim
fi

