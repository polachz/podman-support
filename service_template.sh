#/bin/sh
######################################################
#         CONTAINER SERVICE DEFINITIONS
#####################################################
#specify the service name here. Script creates
#container with same name and generates .service file for
#systemd --user service. The service can be handles directly
#by 'systemctl --user start my_service' etc.. 
SERVICE_NAME="my_service"
#name of pod where the container will be inserted
#if commented out or empty, then container is not
#inserted to any pod and is created globally
POD_NAME="my_pod"
#container repository, name and version. 
#same as known in docker compose yaml
CONTAINER_IMAGE_NAME_AND_VERSION="docker.io/library/nginx:latest"
#UID of the user INSIDE container who is running
#container services and own container files. 
#It have to be numeric UID, not name as wwwdata for example
#Used to set proper owner of files on the filesystem by 
#podman user mapping. 
CONTAINER_USER_UID=1100
#Mount points for the container. Format is 
#local_path:container_path:options
#For more details take look on podman documentation
#If no mount points, please comment it out
CONTAINER_MOUNT_POINTS=(
'/opt/web_container/web_root:/var/www:Z'
'/opt/web_container/config:/etc/httpd/conf:Z'
)
#Environent definitions passed to the container 
#If no environment variables, please comment it out
CONTAINER_ENVIRONMENT_VARS=(
'HTTPD_MAIN_CONF_PATH=/etc/httpd/conf'
'HTTPD_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/httpd/'
)
#Port mappings between host and container.
#If the container is part of the pod, then you have to 
#specify port mapping for the whole pod, not for container
#Otherwise you will get error during port creation process
#this param makes mainly sense for non-pod member containers only
#If no port mappings for the container, please comment it out
CONTAINER_PORT_MAPPINGS=(
'8080:8080'
'8443:8443'
)
#specify here additional parameters for command 'podman container create'
#see podman documentaion for all possibilities
#If additional parameters, leave variable empty or comment it out
CONTAINER_ADDITIONAL_PARAMS="--add-host=mysqlhost:192.168.22.33"

#systemd services dependency definitions
#if no dependencies are necessary, then leave these variables empty
#or comments them out
#!!NOTICE!! this directive don't generate containers for these
#services automatically. Just generate dependency directives
#to systemd service files
#You have to create these services separately by own scripts!!! 

#list of service names for systemd service Wants definition
#SERVICES_WANTS=()
#list of service names for systemd service Requires definition
SERVICES_REQUIRES=('web_mysqld' 'web_ftpsrv' )

#####################################################
#                  END OF DEFINITIONS
#         DO NOT CHANGE ANY LINE BELOW PLEASE
####################################################

LIB_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$LIB_DIR" ]]; then LIB_DIR="$PWD"; fi

if [ -d "$LIB_DIR/podman-support" ]; then LIB_DIR="${LIB_DIR}/podman-support"; fi

if [ -f "$LIB_DIR/podman_support.sh" ]; then
   . "$LIB_DIR/podman_support.sh"
else
   echo "Unable to locate podman_support.h library"
   exit 1
fi


container_svc_main $SERVICE_NAME $1

