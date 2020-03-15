# Podman-Support
Shell scripts to create or remove Podman rootless system services inside pods

This script library allows to create/remove/update rootless container services easily. It is designed to create podman pod and service definition(s) as set of the BASH shell variables and then run bash function to provide required operation.

The repository contains two templates:
- **pod_template.sh** - Create the pod and allows to map it's port(s) to host or remove the pod.
- **service_template.sh** Create or remove the container and systemd service for the container 

To use these templates, copy template to a folder together with *podman_support.sh*, rename the template and then modify the content to fit the container needs. Then by run the shell script created based on the template, you can create or remove the pod or the container and the systemd related service.

If you need to modify the container ot the pod - to upgrade container to latest version or to add a port mapping to the pod for example then you can easily remove current instance then modify the template to reflect new requirements and then re-create the pod or service again.

## pod_template.sh ##
Create the pod (without services) or remove the pod and it's containers if all are already stoppped
## service_template.sh ##
