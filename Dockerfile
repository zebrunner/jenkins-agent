FROM alpine:edge

LABEL maintainer "Vadim Delendik <vdelendik@solvd.com>"

ENV DEBIAN_FRONTEND=noninteractive

#=============
# Set WORKDIR
#=============
WORKDIR /root

#==================
# General Packages
#==================
RUN apk add --no-cache \
    bash \
    openjdk11 \
    tzdata \
    curl \
    git \
    git-fast-import \
    openssh-client \
    bind-tools \
    gnupg \
    lsof && \
    rm -rf /var/lib/apt/lists/* /usr/lib/jvm/java-11-openjdk/demo /usr/lib/jvm/java-11-openjdk/man /usr/lib/jvm/java-11-openjdk/jre/demo /usr/lib/jvm/java-11-openjdk/jre/man

# ADB part
RUN apk add \
    android-tools \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing

# kubectl 
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    kubectl version --client

##===============
## Install Docker
##===============
#RUN apk add --no-cache docker openrc \
#    && rc-update add docker boot

#===============
# Set JAVA_HOME
#===============
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
ENV PATH=$PATH:$JAVA_HOME/bin

#======================
# Install Jenkins swarm
#======================
ENV JENKINS_SLAVE_ROOT="/opt/jenkins"

USER root

RUN mkdir -p "$JENKINS_SLAVE_ROOT"
RUN mkdir -p /opt/apk

# Slave settings
ENV JENKINS_MASTER_USERNAME="jenkins" \
    JENKINS_MASTER_PASSWORD="jenkins" \
    JENKINS_MASTER_URL="http://jenkins:8080/" \
    JENKINS_SLAVE_MODE="exclusive" \
    JENKINS_SLAVE_NAME="swarm-$RANDOM" \
    JENKINS_SLAVE_WORKERS="1" \
    JENKINS_SLAVE_LABELS="" \
    AVD=""

# Set the lang, you can also specify it as as environment variable through docker-compose.yml
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8\
    LC_ALL=en_US.UTF-8

# Install Jenkins slave (swarm)
ADD files/swarm-client-3.24.jar /swarm-client.jar
ADD entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
