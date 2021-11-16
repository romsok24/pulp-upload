FROM python:3.7-slim
RUN apt-get update && apt install jq -y
RUN pip install pulp-cli[pygments] pulp-cli[shell] pulp-cli-deb
COPY pulp_file_packages_processing_docker.sh /root/
WORKDIR /root/
