#!/bin/bash

# Goal:         A bash script for batch processing of packages and files
#               in order to make it available on the given Pulp instance
#               The script is additive (if new artifacts are discovered - the pulp repo will be updated)
# Usage:        ./pulp_file_packages_processing.sh
# Run with:     ubuntu + Pulp CLI
# Version:      21v1103
# Author:       roman.sokalski

 
CUST_BASE_PATH='/var/www/html/rosrepo/'
ARTIFACT_FILTER='*'
ROS_RELEASE='12'
REPO_NAME='ros_repo_'$ROS_RELEASE

echo -e "\n=====Prereqs==========================================\n"
if [[ $# -lt 2 ]] ; then
    echo 'Usage: '$0' pulp_instance_url admin_pass_to_pulp_instance'
    exit 0
fi

cd $CUST_BASE_PATH'bin/'
sudo apt-get install python3-venv python3-pip -y
/usr/bin/python3 -m venv venv_pulp
pip3 install pulp-cli[pygments] pulp-cli[shell] pulp-cli-deb httpie httpie-jwt-auth
source */bin/activate

echo -e "\n=====Creating pulp repo and uploding artifacts=====================\n"
pulp config create --username admin --overwrite --base-url http://$1 --password $2
pulp file repository create --name $REPO_NAME

# Workaround for non ASCI chars in the names:
# sudo apt update && sudo apt install rename
# rename 's/%3a/:/g' $CUST_PATH

echo -e "\n---Process packages index------------------------------------------------------------------\n"
cd $CUST_BASE_PATH && dpkg-scanpackages -m  packages | gzip -9c > Packages.gz
ARTIFACT_SHA256=$(sha256sum Packages.gz | cut -d' ' -f1)
ARTIFACT_HREF=$(pulp artifact upload --file Packages.gz | jq -r '.pulp_href')
CONTENT_HREF=$(pulp file content create --relative-path Packages.gz --sha256 $ARTIFACT_SHA256 | jq -r '.pulp_href')
pulp file repository add --name $REPO_NAME --sha256 $ARTIFACT_SHA256 --relative-path Packages.gz

echo -e "\n#---Process packages-----------------------------------------------------------------------\n"
PULP_REL_PATH_BASE='packages'
CUST_PATH=$CUST_BASE_PATH$PULP_REL_PATH_BASE
if [ ! -d $CUST_PATH ] ; then
    echo -e '\n[ERR] Directory '$CUST_PATH' DOES NOT exists.'
    exit 0
fi
CUST_PATH=$CUST_BASE_PATH$PULP_REL_PATH_BASE'/'$ARTIFACT_FILTER
ARTIFACTS_CNT=$(ls -l $CUST_PATH | wc -l)
c=1
for f in $CUST_PATH; do
    f_NAME=$(echo $f | awk -F '/' '{print $(NF)}')
    PULP_REL_PATH=$PULP_REL_PATH_BASE'/'$f_NAME
    ARTIFACT_SHA256=$(sha256sum $f | cut -d' ' -f1)
    ARTIFACT_HREF=$(pulp artifact upload --file $f | jq -r '.pulp_href')
    CONTENT_HREF=$(pulp file content create --relative-path $PULP_REL_PATH --sha256 $ARTIFACT_SHA256 | jq -r '.pulp_href')
    pulp file repository add --name $REPO_NAME --sha256 $ARTIFACT_SHA256 --relative-path $PULP_REL_PATH
    let PROGRESS=(c*100)/$ARTIFACTS_CNT
    printf "====== Progress:  %.0f %% =======================================\n" "$PROGRESS"
    c=$((c+1))
done

echo -e "\n#---Process files-----------------------------------------------------------------------\n"
PULP_REL_PATH_BASE='files'
CUST_PATH=$CUST_BASE_PATH$PULP_REL_PATH_BASE
if [ ! -d $CUST_PATH ] ; then
    echo -e '\n[ERR] Directory '$CUST_PATH' DOES NOT exists.'
    exit 0
fi
CUST_PATH=$CUST_BASE_PATH$PULP_REL_PATH_BASE'/'$ARTIFACT_FILTER
ARTIFACTS_CNT=$(ls -l $CUST_PATH | wc -l)

if [ ! -d $CUST_PATH ] ; then
    echo 'Directory '$CUST_PATH' DOES NOT exists.'
    exit 0
fi

c=1
for f in $CUST_PATH; do
    f_NAME=$(echo $f | awk -F '/' '{print $(NF)}')
    PULP_REL_PATH=$PULP_REL_PATH_BASE'/'$f_NAME
    ARTIFACT_SHA256=$(sha256sum $f | cut -d' ' -f1)
    ARTIFACT_HREF=$(pulp artifact upload --file $f | jq -r '.pulp_href')
    CONTENT_HREF=$(pulp file content create --relative-path $PULP_REL_PATH --sha256 $ARTIFACT_SHA256 | jq -r '.pulp_href')
    pulp file repository add --name $REPO_NAME --sha256 $ARTIFACT_SHA256 --relative-path $PULP_REL_PATH
    let PROGRESS=(c*100)/$ARTIFACTS_CNT
    printf "====== Progress:  %.0f %% =======================================\n" "$PROGRESS"
    c=$((c+1))
done

echo -e "\n#---Process images-----------------------------------------------------------------------\n"
PULP_REL_PATH_BASE='images'
CUST_PATH=$CUST_BASE_PATH$PULP_REL_PATH_BASE
if [ ! -d $CUST_PATH ] ; then
    echo -e '\n[ERR] Directory '$CUST_PATH' DOES NOT exists.'
    exit 0
fi
CUST_PATH=$CUST_BASE_PATH$PULP_REL_PATH_BASE'/'$ARTIFACT_FILTER
ARTIFACTS_CNT=$(ls -l $CUST_PATH | wc -l)

if [ ! -d $CUST_PATH ] ; then
    echo 'Directory '$CUST_PATH' DOES NOT exists.'
    exit 0
fi

c=1
for f in $CUST_PATH; do
    f_NAME=$(echo $f | awk -F '/' '{print $(NF)}')
    PULP_REL_PATH=$PULP_REL_PATH_BASE'/'$f_NAME
    ARTIFACT_SHA256=$(sha256sum $f | cut -d' ' -f1)
    ARTIFACT_HREF=$(pulp artifact upload --file $f | jq -r '.pulp_href')
    CONTENT_HREF=$(pulp file content create --relative-path $PULP_REL_PATH --sha256 $ARTIFACT_SHA256 | jq -r '.pulp_href')
    pulp file repository add --name $REPO_NAME --sha256 $ARTIFACT_SHA256 --relative-path $PULP_REL_PATH
    let PROGRESS=(c*100)/$ARTIFACTS_CNT
    printf "====== Progress:  %.0f %% =======================================\n" "$PROGRESS"
    c=$((c+1))
done

echo -e "\n=====Creating pulp publ and distr==========================================\n"

PUBL_HREF=$(pulp file publication create --repository $REPO_NAME | jq -r '.pulp_href' )
pulp file distribution destroy --name $(pulp file distribution list | jq '.[].name' | grep $REPO_NAME | sed 's/"//g' )
pulp file distribution create --name $REPO_NAME'_'$(date +"%m%d.%H%M") --base-path $REPO_NAME --publication $PUBL_HREF

echo -e "\n=====End of sccript==========================================\n"
