#/bin/sh
#######################################################
##         POD DEFINITIONS
######################################################
#name of the pod. same name have to be used in service definitions
POD_NAME="my_pod"
#Specify here port mappings between the pod and the host
#aka ports which you have to expose to pod outer world. 
#For example web server port, to allow handle traffic from the Internet
#If you will run things rootless, you can't map any
#host port below 1024 (priviledged ports)
#for all alowed maping parameters and forms, see the podman doc
#NOTE !!Port mapping can't be changed after pod is created
#If you need to change port mapping you have to re-create pod
POD_PORT_MAPPINGS=(
'8080:80'
'8443:443'
)
#specify here additional parameters for command podman pod create
#see podman documentaion for all possibilities
#POD_ADDITIONAL_PARAMS="--add-host=mysqlhost:192.168.22.33"
#
######################################################
##                  END OF DEFINITIONS
##         DO NOT CHANGE ANY LINE BELOW PLEASE
#####################################################

LIB_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$LIB_DIR" ]]; then LIB_DIR="$PWD"; fi
. "$LIB_DIR/podman_support.sh"


pod_main $1

