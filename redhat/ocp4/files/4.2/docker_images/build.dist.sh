#!/usr/bin/env bash

set -e
set -x

wget https://raw.githubusercontent.com/wangzheng422/docker_env/master/redhat/ocp4/files/4.2/docker_images/image.mirror.fn.sh
wget https://raw.githubusercontent.com/wangzheng422/docker_env/master/redhat/ocp4/files/4.2/docker_images/image.mirror.install.sh
wget https://raw.githubusercontent.com/wangzheng422/docker_env/master/redhat/ocp4/files/4.2/docker_images/image.registries.conf.sh
wget https://raw.githubusercontent.com/wangzheng422/docker_env/master/redhat/ocp4/files/4.2/docker_images/install.image.list
wget https://raw.githubusercontent.com/wangzheng422/docker_env/master/redhat/ocp4/files/4.2/docker_images/add.image.load.sh

cat << EOF >>  /etc/hosts
127.0.0.1 registry.redhat.ren
EOF

mkdir /etc/crts/ && cd /etc/crts
openssl req \
   -newkey rsa:2048 -nodes -keyout redhat.ren.key \
   -x509 -days 3650 -out redhat.ren.crt -subj \
   "/C=CN/ST=GD/L=SZ/O=Global Security/OU=IT Department/CN=*.redhat.ren"

cp /etc/crts/redhat.ren.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract

mkdir -p /data/registry
cat << EOF > /etc/docker-distribution/registry/config.yml
version: 0.1
log:
  fields:
    service: registry
storage:
    cache:
        layerinfo: inmemory
    filesystem:
        rootdirectory: /data/registry
    delete:
        enabled: true
http:
    addr: :443
    tls:
       certificate: /etc/crts/redhat.ren.crt
       key: /etc/crts/redhat.ren.key
EOF
# systemctl restart docker
systemctl enable docker-distribution

systemctl restart docker-distribution

podman login registry.redhat.ren -u a -p a

wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.2/release.txt

export BUILDNUMBER=$(cat release.txt | grep 'Name:' | awk '{print $NF}')
echo ${BUILDNUMBER}

wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.2/openshift-client-linux-${BUILDNUMBER}.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.2/openshift-install-linux-${BUILDNUMBER}.tar.gz

tar -xzf openshift-client-linux-${BUILDNUMBER}.tar.gz -C /usr/local/bin/
tar -xzf openshift-install-linux-${BUILDNUMBER}.tar.gz -C /usr/local/bin/

wget --recursive --no-directories --no-parent https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.2/latest/

wget -O ocp4-upi-helpernode-master.zip https://github.com/wangzheng422/ocp4-upi-helpernode/archive/master.zip

wget -O filetranspiler-master.zip https://github.com/wangzheng422/filetranspiler/archive/master.zip

podman pull registry.fedoraproject.org/fedora:latest
podman save registry.fedoraproject.org/fedora:latest | pigz -c > fedora.tgz

podman pull docker.io/library/registry:2
podman save docker.io/library/registry:2 | pigz -c > registry.tgz

export OCP_RELEASE=${BUILDNUMBER}
export LOCAL_REG='registry.redhat.ren'
export LOCAL_REPO='ocp4/openshift4'
export UPSTREAM_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON="pull-secret.json"
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=${LOCAL_REG}/${LOCAL_REPO}:${OCP_RELEASE}
export RELEASE_NAME="ocp-release"


oc adm release mirror -a ${LOCAL_SECRET_JSON} \
--from=quay.io/${UPSTREAM_REPO}/${RELEASE_NAME}:${OCP_RELEASE} \
--to-release-image=${LOCAL_REG}/${LOCAL_REPO}:${OCP_RELEASE} \
--to=${LOCAL_REG}/${LOCAL_REPO}

# /bin/rm -f pull-secret.json

# cd /root
# https://blog.csdn.net/ffzhihua/article/details/85237411
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm
rpm2cpio python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm | cpio -iv --to-stdout ./etc/rhsm/ca/redhat-uep.pem | tee /etc/rhsm/ca/redhat-uep.pem

cd /data/ocp4
# download additinal images
# scp files/4.2/docker_image/* 

# yum -y install jq python3-pip pigz docker
pip3 install yq

# systemctl start docker

# docker login -u ****** -p ******** registry.redhat.io
# docker login -u ****** -p ******** registry.access.redhat.com
# docker login -u ****** -p ******** registry.connect.redhat.com

# podman login -u ****** -p ******** registry.redhat.io
# podman login -u ****** -p ******** registry.access.redhat.com
# podman login -u ****** -p ******** registry.connect.redhat.com

# 以下命令要运行 2-3个小时，耐心等待。。。
bash image.mirror.install.sh

cd /data
tar cf - registry/ | pigz -c > registry.with.operator.hub.tgz 

# cd /data/ocp4
# bash image.mirror.sh
# cd /data
# tar cf - registry/ | pigz -c > registry.with.operator.image.tgz  

# cd /data/ocp4
# bash image.mirror.sample.sh
# cd /data
# tar cf - registry/ | pigz -c > registry.full.with.sample.tgz 

cd /data
tar cf - ocp4/ | pigz -c > ocp4.tgz 

# split -b 10G registry.with.operator.image.tgz registry.
# find /data -maxdepth 1 -type f -exec sha256sum {} \;


