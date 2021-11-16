#!/bin/bash

# Goal:         A bash script for batch processing of container images
#               in order to make it available on the given Pulp container registry instnace
# Usage:        ./pulp_container_images_processing.sh
# Version:      21v1030
# Author:       roman.sokalski@hitachienergy.com

 
CUST_BASE_PATH='/var/www/html/epirepo/'
CUST_PATH=$CUST_BASE_PATH'images/*'
ARTIFACT_FILTER='*'
EPI_RELEASE='13'
REPO_NAME='epi_reg_'$EPI_RELEASE
EPI_REG_NAME='epi_reg_'$(cat  /etc/machine-id)
EPI_REG_URL='http://51.145.162.94:5000'

echo -e "\n=====Prereqs=======================================================\n"
if [[ $# -lt 2 ]] ; then
    echo 'Usage: '$0' pulp_instance_url_with_port admin_pass_to_pulp_instance'
    exit 0
fi

cd $CUST_BASE_PATH'bin/'
sudo apt-get install python3-venv python3-pip -y
/usr/bin/python3 -m venv venv_pulp
pip3 install pulp-cli[pygments] pulp-cli[shell] pulp-cli-deb httpie httpie-jwt-auth
source */bin/activate

echo -e "\n=====Creating pulp repo and uploding artifacts=====================\n"
pulp config create --username admin --overwrite --base-url http://$1 --password $2

EPI_REPOS=$(curl -sk -X GET $EPI_REG_URL'/v2/_catalog' | jq '.repositories[]' | tr -d '"')
EPI_REPOS_CNT=$(echo "$EPI_REPOS" | wc -l)
c=1
for r in $EPI_REPOS; do
    CONT_REPO_NAME=$(pulp container repository create --name $r | jq -r '.name')

    r_TAG=$(curl -sk -X GET $EPI_REG_URL'/v2/'$r'/tags/list' | jq '.tags[]' | tr -d '"')
    printf "[INF] Processing %s:%s container image\n" "$r" "$r_TAG"
    
    echo $(pulp container remote create --name $r --url $EPI_REG_URL --upstream-name $r --tls-validation false | jq -r '.pulp_created')
    TASK_HREF=$(pulp container repository sync --name $CONT_REPO_NAME --remote $r | jq -r '.task')
    
    # REG_PATH=$(pulp container distribution create --name $REPO_NAME'_'$(date +"%m%d.%H%M") --base-path $r --repository $CONT_REPO_NAME  | jq -r '.registry_path')
    REG_PATH=$(pulp container distribution create --name $r --base-path $r --repository $CONT_REPO_NAME  | jq -r '.registry_path')
    printf "[INF] Image available at:  %s:%s \n" "$REG_PATH" "$r_TAG"

    let PROGRESS=(c*100)/$EPI_REPOS_CNT
    printf "====== Progress:  %.0f %% =======================================\n" "$PROGRESS"
    c=$((c+1))
done

echo -e "\n=====Creating pulp distro object====================================\n"
# DISTR_HREF=$(pulp container distribution create --name $REPO_NAME'_'$(date +"%m%d.%H%M") --base-path $REPO_NAME'_basename' --repository $CONT_REPO_NAME |  jq -r '.pulp_href' )
# REG_PATH=$(pulp show --href $DISTR_HREF | jq '.registry_path' | sed 's/"//g')
# printf "[INF] Registry available at:  %s \n" "$REG_PATH"

printf "\n=====End of sccript=================================================\n"
