#/bin/sh

FG_RED='\033[00;31m'
FG_GREEN='\033[00;32m'
FG_YELLOW='\033[00;33m'
FG_BLUE='\033[00;34m'
FG_NO_COLOR='\033[00;39m'

function file_exist {
   if [ -f $1 ];
   then
      #exit code 0 is success in the BASH
      return 0
   else
      #exit <>0 is error (false) in bash
      return 1
   fi
}

function check_line_presence {
   local GREP_FOUND_PATTERN=$(grep "$1" "$2")
   if [ -z "$GREP_FOUND_PATTERN" ]
   then
      return 1
   else
      return 0
   fi
}

function replace_or_add_line {
#params line_search_pattern, new_line_value _file_for_replace_or_add
   if check_line_presence "$1" "$3"
   then
     #line present. replace, use ~ as delimiter instead / due filenames
     sed -i "/^#/!s~.*$1.*~$2~g" "$3"
   else
     #add line at the end of file
     echo "$2" >> "$3"
   fi

}

#Create mount points if not exists
#$1 - Container user PID
#$@ - array of mount points in podman form local_path:container_path:options

function create_mount_points_on_fs() {
   
   local USR_PID="$1"
   shift
   local ARR=("$@")
   local IFS_BKP=$IFS  

   for LINE in "${ARR[@]}"; do
      IFS=":"
      read -ra PARTS <<< "$LINE"
      IFS=$IFS_BKP
      FS_DIR="${PARTS[0]}"
      #Now check if dir exist, if not, create
      if [ ! -d "$FS_DIR" ]; then
         echo "Creating mount point $FS_DIR...${FG_NO_COLOR}"
         mkdir -p "$FS_DIR"
      fi
      if [ -d "$FS_DIR" ]; then
         #change owner on proper PID
         podman unshare chown -R "$USR_PID":"$USR_PID" "$FS_DIR"
      else
         echo -e "${FG_RED}Mount point $FS_DIR was not created!${FG_NO_COLOR}"
  	 return 1
      fi	 
   done
   return 0
}

#$@ - array of mount points in podman form local_path:container_path:options

function verify_mount_points_on_fs() {

   local USR_PID="$1"
   shift
   local ARR=("$@")
   local IFS_BKP=$IFS
   
   for LINE in "${ARR[@]}"; do
      IFS=":"
      read -ra PARTS <<< "$LINE"
      IFS=$IFS_BKP
      FS_DIR="${PARTS[0]}"
      #Now check if dir exist, if not, report
      if [ ! -d "$FS_DIR" ]; then
         echo -e "${FG_RED}Mount point $FS_DIR is missing!...${FG_NO_COLOR}"
         return 1
      fi
   done
   return 0
}



#build the mount points string for use in podman create command -v local:container:flags -v local2.....
#$1 name ov the variable where final string will be placed
#$@ - array of mount points in podman form local_path:container_path:options

function get_mount_points_params_string() {
   
   local MNT_STR=""
   local OUT_NAME="$1"
   shift 
   local ARR=("$@")

   for LINE in "${ARR[@]}"; do
      MNT_STR="${MNT_STR} -v $LINE"
   done
   eval "$OUT_NAME=\${MNT_STR}"
}

function get_environment_params_string() {

   local ENV_STR=""
   local OUT_NAME="$1"
   shift
   local ARR=("$@")

   for LINE in "${ARR[@]}"; do
      ENV_STR="${ENV_STR} -e $LINE"
   done
   eval "$OUT_NAME=\${ENV_STR}"
}

function get_port_mapping_params_string() {

   local PORTS_STR=""
   local OUT_NAME="$1"
   shift
   local ARR=("$@")

   for LINE in "${ARR[@]}"; do
      PORTS_STR="${PORTS_STR} -p $LINE"
   done
   eval "$OUT_NAME=\${PORTS_STR}"
}


#use VAR=$(get_services_dir_path)

function get_services_dir_path() {

   local DIRPATH="$HOME/.config/systemd/user"
   echo "$DIRPATH"
}

#use VAR=$(get_full_service_file_path $svc_name)
#$1 service aka container name

function get_full_service_file_path() {
   
   local FNAME="$1.service"
   local DIRPATH=$(get_services_dir_path)
   local FULL_PATH="${DIRPATH}/${FNAME}"
   
   echo "$FULL_PATH"
}

function check_if_service_exists() {
    local n=$1
    if [[ $(systemctl list-units --user --all -t service --full --no-legend "$n.service" | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

#$1 service aka container name

function check_if_service_running() {

   if systemctl --user --quiet is-active "$1"; then
      #exit code 0 is success in the BASH
      return 0
   else
      #exit <>0 is error (false) in bash
      return 1
   fi

}

#$1 service aka container name

function check_if_service_file_exists() {
 
   local FPATH=$(get_full_service_file_path $1) 
   if [ -f $FPATH ];
   then
      #exit code 0 is success in the BASH
      return 0
   else
      #exit <>0 is error (false) in bash
      return 1
   fi
}

#$1 container name

function check_if_container_exists() {
   if podman container exists "$1"; then
      return 0
   else
      return 1
   fi
}

function check_if_container_running() {
   
   if [[ $(podman ps | grep "$1" | rev | awk '{print $1}' | rev) == "$1" ]]; then
      return 0
   else
      return 1
   fi
}

#$1 pod name

function check_if_pod_exists() {

if podman pod exists "$1"; then
      return 0
   else
      return 1
   fi
}

#$1 pod name

function get_pod_id() {

   if podman pod list | grep -q "$1"; then
      local PI=$(podman pod list | grep "$1" | awk '{print $1}' )
      echo "$PI"
   else
      echo '\0'
   fi
}

#$1 pod name

function check_if_pod_run_any_container() {

   if ! check_if_pod_exists "$1"; then
      #no pod, nothing run, false
      return 1
   fi
   local POD_ID=$(get_pod_id "$1")

   if $(podman ps -p | grep -q "$1"); then
      return 0
   else
      return 1
   fi
}
#$1 Name of result variable
#$2 Name of pod
function list_of_pod_containers() {
   if ! check_if_pod_exists "$2"; then
      #no pod, nothing run, false
      eval "$1='\0'"
      return 1
   fi
   local POD_ID=$(get_pod_id $2)
   echo "POD ID $POD_ID"
   local RAW_DATA=$(podman container list -ap |  grep "$POD_ID" | rev |  awk '{print $2}' | rev | grep -v -- "-infra" | tr '\n' ' ' )
   eval "$1=(\${RAW_DATA})"
}
#$1 container name

function check_if_service_file_can_be_created() {

   if check_if_service_file_exists $1; then
      echo -e "${FG_RED}Service file for container $1 already exists. Please fix this !!${FG_NO_COLOR}"
      return 1
   fi
   return 0

}
#$1 container name

function check_if_container_can_be_created() {

   #check if pod name is defined
   if [ ! -z "$POD_NAME" ]; then
      #in this case the pod must exists!
      if ! check_if_pod_exists "$POD_NAME"; then
         echo -e "${FG_RED}The Pod  $POD_NAME doesn't exist. Please fix this !!${FG_NO_COLOR}" 
         return 1
      fi
   fi

   if check_if_container_exists $1 ; then
      echo -e "${FG_RED}Container $1 already exists!!${FG_NO_COLOR}"
      return 1
   fi
   return 0
}

#Parameters except container name have to be passed here through global variables:
#$1 - container name
#CONTAINER_IMAGE_NAME_AND_VERSION - name of the container and version for ecample 
#POD_NAME - name of pod where container will be inserted or empty to create container without pod
#CONTAINER_IMAGE_NAME_AND_VERSION - name of the container and version for example "docker.elastic.co/elasticsearch/elasticsearch:6.8.7"
#CONTAINER_USER_UID - UID of the user used to run service(s) inside the container
#CONTAINER_MOUNT_POINTS empty or array of mount points in podman form local_path:container_path:options
#CONTAINER_ENVIRONMENT_VARS empty or definition of the container environment variables passed to the container
#CONTAINER_PORT_MAPPINGS empty or definitions of the port mappings of the container
#CONTAINER_ADDITIONAL_PARAMS - additional parameters for podman, if any
function create_container() {
  
   local CMD_LINE=""
   
   if ! check_if_container_can_be_created $1; then
      return 1
   fi
   #create missing mount points, and chown them to user
   if ! create_mount_points_on_fs $CONTAINER_USER_UID "${CONTAINER_MOUNT_POINTS[@]}"; then
      echo -e "${FG_YELLOW}Unable to continue with creating $1 container...${FG_NO_COLOR}"
      return 1
   fi
   
   #build podman command line

   CMD_LINE="podman create -d --name $1"
   #check if pod name is defined
   if [ ! -z "$POD_NAME" ]; then
      CMD_LINE="${CMD_LINE} --pod $POD_NAME"
   fi

   #mount points
   if [ ! -z "$CONTAINER_MOUNT_POINTS" ]; then
      MOUNT_POINT_LINE_PARAMS=""
       get_mount_points_params_string "MOUNT_POINT_LINE_PARAMS" "${CONTAINER_MOUNT_POINTS[@]}"
      CMD_LINE="${CMD_LINE} $MOUNT_POINT_LINE_PARAMS"
   fi

   #environment
   if [ ! -z "$CONTAINER_ENVIRONMENT_VARS" ]; then
      ENV_LINE_PARAMS=""
      get_environment_params_string "ENV_LINE_PARAMS" "${CONTAINER_ENVIRONMENT_VARS[@]}"      
      CMD_LINE="${CMD_LINE} $ENV_LINE_PARAMS"
   fi
   
   #port mappings
   if [ ! -z "$CONTAINER_PORT_MAPPINGS" ]; then
      PORT_MAP_LINE_PARAMS=""
      get_port_mapping_params_string "PORT_MAP_LINE_PARAMS" "${CONTAINER_PORT_MAPPINGS[@]}"
      CMD_LINE="${CMD_LINE} $PORT_MAP_LINE_PARAMS"
   fi

   #Additional parameters, if any
   if [ ! -z "$CONTAINER_ADDITIONAL_PARAMS" ]; then
      CMD_LINE="${CMD_LINE} $CONTAINER_ADDITIONAL_PARAMS"
   fi

   CMD_LINE="${CMD_LINE} $CONTAINER_IMAGE_NAME_AND_VERSION"

   #now run the podman
   eval ${CMD_LINE}

   if check_if_container_exists "$1"; then
      echo -e "${FG_GREEN}Container $1 has been successfully created.${FG_NO_COLOR}"
      return 0
   else
      echo -e "${FG_RED}Container $1 hasn't been created.${FG_NO_COLOR}"
      return 1
   fi
}

#$1 - container name

function modify_service_target_in_file {

   if check_if_service_file_exists "$1"; then
     local SVC_FILE_PATH=$(get_full_service_file_path $1)
     replace_or_add_line "WantedBy" "WantedBy=default.target" "$SVC_FILE_PATH"
     return 0
   fi
   return 1
}

#$1 out variable name
#$@ array of names

function get_services_list_string() {

   local LIST_STR=""
   local OUT_NAME="$1"
   shift
   local ARR=("$@")

   for SVC_NAME in "${ARR[@]}"; do
      if [ -z "$LIST_STR" ]; then
	 LIST_STR="$SVC_NAME.service"
      else
         LIST_STR="${LIST_STR} $SVC_NAME.service"
      fi
   done
   eval "$OUT_NAME=\${LIST_STR}"
}

#Parameters except container name have to be passed here through global variables:
#$1 - container name
#SERVICES_WANTS - list of container names (services) what are set wants in systemd
#SERVICES_REQUIRES -list of container names (services) what are set requires in systemd

function generate_service_dependency_in_file() {

   if ! check_if_service_file_exists "$1"; then
      echo -e "${FG_RED}The service file for container $1 doesn't exist!${FG_NO_COLOR}"
      return 1
   fi
   WANTS_STR=""
   REQS_STR=""
   AFTER_STR=""

   if [ ! -z "$SERVICES_WANTS" ]; then
      get_services_list_string "WANTS_STR" "${SERVICES_WANTS[@]}"
      AFTER_STR="$WANTS_STR"
   fi
   if [ ! -z "$SERVICES_REQUIRES" ]; then
     get_services_list_string "REQS_STR" "${SERVICES_REQUIRES[@]}"
     if [ -z "$AFTER_STR" ]; then
         AFTER_STR="$REQS_STR"
      else
         AFTER_STR="${AFTER_STR} $REQS_STR"
      fi
   fi

   if [ ! -z "$AFTER_STR" ]; then   
      local SVC_FILE_PATH=$(get_full_service_file_path $1)
      local STR_TO_APPEND="\n[Unit]\n"
      if [ ! -z "$WANTS_STR" ]; then
         STR_TO_APPEND="${STR_TO_APPEND}Wants=${WANTS_STR}\n"
      fi
      if [ ! -z "$REQS_STR" ]; then
         STR_TO_APPEND="${STR_TO_APPEND}Requires=${REQS_STR}\n"
      fi
      STR_TO_APPEND="${STR_TO_APPEND}After=${AFTER_STR}\n"
      echo -e "$STR_TO_APPEND" >> "$SVC_FILE_PATH"
   fi
}

#$1 - container name

function generate_container_service_file() {

   if ! check_if_container_exists "$1"; then
      echo -e "${FG_RED}Unable to generate service file. Container $1 doesn't exist!${FG_NO_COLOR}"
      return 1
   fi
   if check_if_service_file_exists "$1"; then
      echo -e "${FG_RED}Unable to generate service file for container $1 because the file already exists!${FG_NO_COLOR}"
      return 1
   fi
   local SVC_DIR=$(get_services_dir_path)
   local SVC_FILE_PATH=$(get_full_service_file_path $1)
   if [ ! -d "$SVC_DIR" ]; then
      echo -e "${FG_YELLOW}Services dir  $SVC_DIR is missing. Going to create it...${FG_NO_COLOR}"
      mkdir -p "$SVC_DIR"
   fi
   if [ ! -d "$SVC_DIR" ]; then
      echo -e "${FG_RED}Services dir can't be created. Unable to create service file!${FG_NO_COLOR}"
      return 1
   fi
   
   podman generate systemd --name "$1" > "$SVC_FILE_PATH"
   
   if check_if_service_file_exists "$1"; then
      #Replace target to fit user rootless service
      modify_service_target_in_file $1
      generate_service_dependency_in_file $1
      #reload daemon files
      systemctl --user daemon-reload
      echo -e "${FG_GREEN}Container $1 service file has been successfully created.${FG_NO_COLOR}"
      return 0
   else
      echo -e "${FG_RED}Container $1 service file hasn't been created.${FG_NO_COLOR}"
      return 1
   fi
   return 0
}

#Parameters except container name have to be passed here through global variables:
#$1 - container name
#CONTAINER_IMAGE_NAME_AND_VERSION - name of the container and version for ecample
#POD_NAME - name of pod where container will be inserted or empty to create container without pod
#CONTAINER_IMAGE_NAME_AND_VERSION - name of the container and version for example "docker.elastic.co/elasticsearch/elasticsearch:6.8.7"
#CONTAINER_USER_UID - UID of the user used to run service(s) inside the container
#CONTAINER_MOUNT_POINTS empty or array of mount points in podman form local_path:container_path:options
#CONTAINER_ENVIRONMENT_VARS empty or definition of the container environment variables passed to the container
#CONTAINER_PORT_MAPPINGS empty or definitions of the port mappings of the container
#CONTAINER_ADDITIONAL_PARAMS - additional parameters for podman, if any

function create_container_and_generate_service() {
   if ! check_if_container_can_be_created $1; then
      return 1
   fi
   if ! check_if_service_file_can_be_created $1; then
      return 1
   fi
   if create_container $1; then
      if generate_container_service_file $1; then
         return 0
      fi
   fi
   return 1
}
#$1 - container name

function delete_container() {
   
   if ! check_if_container_exists "$1"; then
      echo -e "${FG_YELLOW} The container $1 doesn't exist ...${FG_NO_COLOR}"
      return 0
   fi

   if check_if_container_running "$1"; then
      echo -e "${FG_YELLOW}Container $1 is running!! Please stop it before continue.${FG_NO_COLOR}"
      return 1
   fi
   podman rm "$1"

   if [ -f "$SERVICE_FILE_PATH" ]; then
      echo "Removing  $SERVICE_FILE_NAME ..."
      rm -f "$SERVICE_FILE_PATH"
   fi
}

function remove_service_file() {

   if ! check_if_service_file_exists "$1"; then
      echo -e "${FG_YELLOW} The service file for the container $1 doesn't exist ...${FG_NO_COLOR}"
      return 0
   fi
   if check_if_service_running "$1"; then
      echo -e "${FG_YELLOW}Service $1 is running!! Please stop it before continue.${FG_NO_COLOR}"
      return 1
   fi
   SVC_FILE_PATH=$(get_full_service_file_path $1)
   rm -f "$SVC_FILE_PATH"
   if check_if_service_file_exists "$1"; then
      echo -e "${FG_RED} The service file for the container $1 can't be deleted!${FG_NO_COLOR}"
      return 1
   else
      echo -e "${FG_GREEN} The service file for the container $1 has been successfully deleted.${FG_NO_COLOR}"
      return 0
   fi
}

function delete_container_and_remove_service() {
   
   if check_if_service_running "$1"; then
      echo -e "${FG_YELLOW}Service $1 is running!! Please stop it before continue.${FG_NO_COLOR}"
      return 1
   fi
   if check_if_container_running "$1"; then
      echo -e "${FG_YELLOW}Container $1 is running!! Please stop it before continue.${FG_NO_COLOR}"
      return 1
   fi

   if remove_service_file $1; then
      if delete_container $1; then
         return 0
      fi
   fi
   return 1
}

#Parameters have to be passed here through global variables:
#POD_NAME - name of pod where container will be inserted or empty to create container without pod
#POD_PORT_MAPPINGS empty or definitions of the pod port mappings (ip:hostPort:podPort | ip::podPort | hostPort:podPort | podPort)
#POD_ADDITIONAL_PARAMS - additional parameters for podman, if any
function create_pod() {

   local CMD_LINE=""
   if [ -z "$POD_NAME" ]; then
      echo -e "${FG_RED}CreatePod: Pod name have to be defined in POD_NAME variable!${FG_NO_COLOR}"
      return 1
   fi

   if check_if_pod_exists $POD_NAME; then
      echo -e "${FG_RED}CreatePod: Pod $POD_NAME already exists!${FG_NO_COLOR}"
      return 1
   fi

   #build podman command line

   CMD_LINE="podman pod create --name $POD_NAME"

   #port mappings
   if [ ! -z "$POD_PORT_MAPPINGS" ]; then
      PORT_MAP_LINE_PARAMS=""
      get_port_mapping_params_string "PORT_MAP_LINE_PARAMS" "${POD_PORT_MAPPINGS[@]}"
      CMD_LINE="${CMD_LINE} $PORT_MAP_LINE_PARAMS"
   fi

   #Additional parameters, if any
   if [ ! -z "$POD_ADDITIONAL_PARAMS" ]; then
      CMD_LINE="${CMD_LINE} $POD_ADDITIONAL_PARAMS"
   fi

   #now run the podman
   eval ${CMD_LINE}

   if check_if_pod_exists $POD_NAME; then
      echo -e "${FG_GREEN}Pod $POD_NAME has been successfully created.${FG_NO_COLOR}"
 else
      echo -e "${FG_RED}Pod $POD_NAME hasn't been created.${FG_NO_COLOR}"
      return 1
   fi
}

#Parameters have to be passed here through global variables:
#POD_NAME - name of pod where container will be inserted or empty to create container without pod
#POD_PORT_MAPPINGS empty or definitions of the pod port mappings (ip:hostPort:podPort | ip::podPort | hostPort:podPort | podPort)
#POD_ADDITIONAL_PARAMS - additional parameters for podman, if any
function remove_pod() {

   local CMD_LINE=""
   if [ -z "$POD_NAME" ]; then
      echo -e "${FG_RED}RemovePod: Pod name have to be defined in POD_NAME variable!${FG_NO_COLOR}"
      return 1
   fi

   if ! check_if_pod_exists $POD_NAME; then
      echo -e "${FG_YELLOW} The pod $POD_NAME doesn't exist ...${FG_NO_COLOR}"
      return 0
   fi

   if check_if_pod_run_any_container $POD_NAME; then
       echo -e "${FG_YELLOW} The pod $POD_NAME contain running containers ...${FG_NO_COLOR}"
      return 0
   fi

   list_of_pod_containers "POD_CONTAINERS" "$POD_NAME"
   
   for CONTAINER_NAME in "${POD_CONTAINERS[@]}"; do
      echo "Removing container $CONTAINER_NAME from POD $POD_NAME"
      delete_container_and_remove_service "$CONTAINER_NAME"
   done
   #FINALLY kill the pod 
   podman pod rm "$POD_NAME"
}

#$1 Name of the service (and container) how it will be named in the podman
#$2 command line first argument - type of operation

function container_svc_main() {
   
   local SERVICE_NAME=$1	
   local COMMAND=$2
   case "$COMMAND" in
   create)
      create_container_and_generate_service $SERVICE_NAME
      ;;
   delete)
       delete_container_and_remove_service $SERVICE_NAME
      ;;
   remove)
      delete_container_and_remove_service $SERVICE_NAME
      ;;
   *)
      echo $"Usage $0 {create|delete|remove}"
      exit 1
esac

}

#$1 Name of the service (and container) how it will be named in the podman
#$2 command line first argument - type of operation

function pod_main() {
   local COMMAND=$1
   case "$COMMAND" in
   create)
      create_pod
      ;;
   delete)
      remove_pod
      ;;
   remove)
      remove_pod
      ;;
   *)
      echo $"Usage $0 {create|delete|remove}"
      exit 1
   esac

}
