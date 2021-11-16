#  Pulp custom repository and registry PoC

- [ Pulp custom repository and registry PoC](#-pulp-custom-repository-and-registry-poc)
  - [Qusickstart Pulp TST env installation](#qusickstart-pulp-tst-env-installation)
  - [Qusickstart Pulp CLI env installation](#qusickstart-pulp-cli-env-installation)
- [Pulp Doc reference](#pulp-doc-reference)
- [PoC use cases](#poc-use-cases)
- [Create a container registry](#create-a-container-registry)
- [Create a file repository example](#create-a-file-repository-example)
- [Securing the docker repo with self signed SSL cert](#securing-the-docker-repo-with-self-signed-ssl-cert)
- [Create deb repo](#create-deb-repo)


## Qusickstart Pulp TST env installation

https://pulpproject.org/pulp-in-one-container/

```
cd $YOUR_PULP_PATH 
sudo mkdir settings pulp_storage pgsql containers

echo "TOKEN_SERVER='http://$(hostname):24817/token/'
TOKEN_SIGNATURE_ALGORITHM='ES256'
PUBLIC_KEY_PATH='/etc/pulp/cert/public_key.pem'
PRIVATE_KEY_PATH='/etc/pulp/cert/private_key.pem'
CONTENT_ORIGIN='http://$(hostname):80'
ANSIBLE_API_HOSTNAME='http://$(hostname):80'
ANSIBLE_CONTENT_HOSTNAME='http://$(hostname):80/pulp/content'
TOKEN_AUTH_DISABLED=True" >> settings/settings.py

docker run -d -p 80:80 --name pulp -v "$(pwd)/settings":/etc/pulp -v "$(pwd)/pulp_storage":/var/lib/pulp -v "$(pwd)/pgsql":/var/lib/pgsql -v "$(pwd)/containers":/var/lib/containers -v "/etc/timezone:/etc/timezone:ro" -v "/etc/localtime:/etc/localtime:ro" -v "/etc/hosts:/etc/hosts:ro" pulp/pulp

sudo docker exec -it pulp bash -c 'pulpcore-manager reset-admin-password'
```


## Qusickstart Pulp CLI env installation
```
pip install pulp-cli[pygments] pulp-cli[shell] pulp-cli-deb
pulp config create --username admin --base-url http://localhost:8080 --password
pulp status
```

# Pulp Doc reference
Architecure:
![](https://docs.pulpproject.org/pulpcore/_images/architecture.png)

[PulpCore](https://docs.pulpproject.org/pulpcore/concepts.html)

![Content Unit add to repo](https://docs.pulpproject.org/pulpcore/_images/concept-add-repo.png)

Building phases order:
artefakt -> content -> repo


[API](https://docs.pulpproject.org/pulp_file/restapi.html#operation/repositories_file_file_versions_list)

[Container plugin](https://docs.pulpproject.org/pulp_container/)



![image info](https://docs.pulpproject.org/pulp_deb/_images/upload.svg)



# PoC use cases
# Create a container registry
```
BASE_ADDR='http://52.169.180.91:24816"
BASE_ADDR='http://127.0.0.1:8080"

# Create a Pulp Repository
REPO_HREF=$(curl -o - -w "%{http_code}"  --netrc-file apic_romanazure.netrc -X POST -H "Content-Type: application/json" -d @apic_reg_repo_create.yaml  $BASE_ADDR/pulp/api/v3/repositories/container/container/ | jq  -r '.pulp_href')
echo "Write down the repo HREF: "

#Create a remote for repo to sync with
ros_dev_container=$(curl -k -X GET http://customreg.ros.local:5000/v2/_catalog | jq '.repositories[]')
echo "Creating a remote that points to an external source of container images."
#for name in $ros_dev_container; do echo $name ; done;
for name in $ros_dev_container;
do
  echo "Creating remote for: $name "
  http POST $BASE_ADDR/pulp/api/v3/remotes/container/container/ name=$name url='http://customreg.ros.local:5000/v2/_catalog' upstream_name=$name --verify false
done

# Sync the pulp registry with the remote
<!-- curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_reg_remote_sync.yaml   $BASE_ADDR"/pulp/api/v3/repositories/container/container/65c624eb-aca7-4605-956f-c3ab072a6f4d/sync/" -->

REG_ID=$(echo $REG_HREF | awk -F '/' '{print $8}')
get_remotes=$(http --session roman GET $BASE_ADDR/pulp/api/v3/remotes/container/container/ --verify false | jq -r '.results[].pulp_href')
for remote in $get_remotes;
do
  echo "Syncying $remote with pulp"
  http --session roman POST $BASE_ADDR/pulp/api/v3/repositories/container/container/$REG_ID/sync/ remote=$remote mirror=False --verify false
done


# Create a container Distribution to serve the repo
 curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_reg_distr.yaml  $BASE_ADDR"/pulp/api/v3/distributions/container/container/"

# List tags from registry
curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X GET -H "Content-Type: application/json" $BASE_ADDR"/pulp/api/v3/content/container/tags/" | jq '.'


#Test our new container registry
echo $BASE_ADDR
docker login  $BASE_ADDR
docker pull vault:1.7.0

# Remove repository and remotes
# pulp container repository list | jq '.[].name' | tr -d '\"'  | xargs -L1 pulp container repository destroy --name; pulp container remote list | jq '.[].name' | tr -d '\"'  | xargs -L1 pulp container remote destroy --name; pulp container distribution list | jq '.[].name' | tr -d '\"'  | xargs -L1 pulp container distribution destroy --name

```
...or with pulp CLI:
```
pulp container repository create --name <name>
pulp container remote create --name <rname> --url <rurl> --upstream-name <uname> 
pulp container repository sync --name <name> --remote <rname>

# If the remote registry URL is signed with custome cert, than you nee to add this cert to the pulp:

yum install ca-certificates 
update-ca-trust force-enable
cp <yourCA>.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract

```
# Create a file repository example
```
pulp artifact upload  --file apic_add2repo.yaml
pulp artifact upload  --file apic_publishrepo.yaml
pulp artifact upload  --file /tmp/vault-k8s-0.10.0.tar
pulp file content create --relative-path apic_add2repo.yaml --sha256 80de3076c0870334ca25edddb31001a44862dcf3939dd6f6de8350ad3b065a09
pulp file content show --href /pulp/api/v3/content/file/files/f648c460-da36-4f5c-a2f6-700e28a377b7/
pulp file content create --relative-path files/apic_add2repo.yaml --sha256 80de3076c0870334ca25edddb31001a44862dcf3939dd6f6de8350ad3b065a09
pulp file content create --relative-path images/vault-k8s-0.10.0.tar --sha256 8b6e25815f0916c4953b03d528f982e73a6bbde2f8f6567137bd9208ef336d51
pulp file content create --relative-path images_centos74/vault-k8s-0.10.0.tar --sha256 8b6e25815f0916c4953b03d528f982e73a6bbde2f8f6567137bd9208ef336d51
pulp file repository create --name ros_repo_09
pulp file repository add --name ros_repo_09 --relative-path files/apic_add2repo.yaml --sha256 80de3076c0870334ca25edddb31001a44862dcf3939dd6f6de8350ad3b065a09
pulp file repository add --name ros_repo_09 --relative-path images/vault-k8s-0.10.0.tar --sha256 8b6e25815f0916c4953b03d528f982e73a6bbde2f8f6567137bd9208ef336d51
pulp file repository add --name ros_repo_09 --relative-path images_centos74/vault-k8s-0.10.0.tar --sha256 8b6e25815f0916c4953b03d528f982e73a6bbde2f8f6567137bd9208ef336d51

http --session roman GET http://127.0.0.1:8080/pulp/api/v3/content/file/files/?repository_version=/pulp/api/v3/repositories/file/file/f1d8df94-5ee3-4556-8b70-c4679369cd2c/versions/1/
pulp file publication create --repository ros_repo_09
pulp file distribution create --name $(date +"%D") --base-path ros09 --publication /pulp/api/v3/publications/file/file/95bf0636-704b-4fc4-a8bf-2adf80323cce/
```
...or using a bulp upload [tool](bin/pulp_file_packages_processing.sh):

![bulp upload](img/bulp_upload.jpg)



# Securing the docker repo with self signed SSL cert
```
#Run as root both pn reg machine and on client:
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 365 -out ca.crt # file extensions are important!
mkdir -p /etc/docker/certs.d/customreg.ros.local:5000
mv ca* /etc/docker/certs.d/customreg.ros.local:5000/

```


# Create deb repo
```
curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_repo_create.yaml http://127.0.0.1:8080/pulp/api/v3/repositories/deb/apt/
```
<!-- ## Create a remote
```
curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_repo_remote.yaml http://127.0.0.1:8080/pulp/api/v3/remotes/deb/apt/
``` -->

<!-- ## Create a publication
```
curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_repo_publication.yaml http://127.0.0.1:8080/pulp/api/v3/publications/deb/apt/
``` -->

## Upload content
```
pulp file content upload --file pulp_storage/telnet_0.17-41_amd64.deb --relative-path telnet_0.17-41_amd64.deb
```

## Add Content to Repository
```
curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_add2repo.yaml http://127.0.0.1:8080/pulp/api/v3/repositories/deb/apt/e7c61aaa-3ebd-4b15-b8f5-f0704364cad9/modify/
```

## Create a Publication

```
curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_publishrepo.yaml http://127.0.0.1:8080/pulp/api/v3/publications/deb/apt/ 
```
## Pulp 'Distribution'
![](https://docs.pulpproject.org/pulpcore/_images/concept-publish.png)

## Sync deb repo
```
curl -o - -w "%{http_code}"  --netrc-file apic_roman.netrc -X POST -H "Content-Type: application/json" -d @apic_syncrepo.yaml http://127.0.0.1:8080/pulp/api/v3/repositories/deb/apt/e7c61aaa-3ebd-4b15-b8f5-f0704364cad9/sync/

# Server Error (500)
```
# Create RPM repo
```
http --session=roman POST "$BASE_ADDR"/pulp/api/v3/repositories/rpm/rpm/ name="centos-repo"
http --session=roman --form POST "$BASE_ADDR"/pulp/api/v3/remotes/rpm/rpm/ name='centos_remote'
url='http://mirror.centos.org/centos/7/os/x86_64/' policy='on_demand'
http --session=roman POST "$BASE_ADDR"/pulp/api/v3/repositories/rpm/rpm/60d8141e-335a-4d79-84ae-9fa839a89ca9/sync/ remote="/pulp/api/v3/remotes/rpm/rpm/68c82777-3385-4ff5-9bfb-d5aa438e7a0a/"
pulp task list --limit=1
```
## (optional) update remote
```
http --session=roman PUT "$BASE_ADDR"/pulp/api/v3/remotes/rpm/rpm/68c82777-3385-4ff5-9bfb-d5aa438e7a0a/ name='centos_remote' url='http://mirror.centos.org/centos/7/os/x86_64/'
```


# Running batch upload scripts from the Docker container

```
cd /path/to/Dockerfile/
docker build -t pulp_cli . 
docker run -dt --rm --name p_cli -v /home/ros/dane/ros_customrepo/:/custom-repo/ pulp_cli # add --add-host=localhost:host-gateway  if you;re running pulp on your local machine
docker exec -it p_cli /bin/bash
echo "xx.yy.zz.ww      yourpulp.instance.local" >> /etc/hosts  # run it inside the container
```

## Custom repo general example ( using docker/registry )

 ```
curl -k -X GET https://customreg.ros.local:5010/v2/_catalog
curl -u user:pass http://pulp-vm3.cbs.hasops.com/v2/vault/tags/list

sudo docker pull customreg.ros.local:5010/istio/proxyv2 http://localhost:8080/pulp/api/v3/repositories/deb/apt
```

