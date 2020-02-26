FROM alpine:3.11.3

LABEL maintainer "Alex Khursevich <alex@qaprosoft.com>"

ENV DEBIAN_FRONTEND=noninteractive

#=============
# Set WORKDIR
#=============
WORKDIR /root

#==================
# General Packages
#==================
RUN apk add --no-cache \
    openjdk8 \
    ca-certificates \
    tzdata \
    unzip \
    curl \
    wget \
    qt5-qtbase-dev \
    #libgconf-2-4 \
    xvfb-run \
    socat \
    git \
    openssh \
    bind-tools \
    apt-transport-https --arch=amd64
#    software-properties-common
RUN rm -rf /var/lib/apt/lists/*

#===============
# Install Docker
#===============
RUN apk add docker
RUN rc-update add docker boot
RUN service docker start

#===============
# Install Maven 3.5.2
#===============
RUN cd /opt && \
    wget https://archive.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.zip && \
    unzip apache-maven-3.5.2-bin.zip && \
    rm apache-maven-3.5.2-bin.zip && \
    mv apache-maven-3.5.2/ maven/

#===============
# Set JAVA_HOME and M2_HOME
#===============
ENV JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/jre" \
    M2_HOME="/opt/maven" \
    MAVEN_HOME="/opt/maven"
ENV PATH=$PATH:$JAVA_HOME/bin:$M2_HOME/bin

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

# Install locales and declare en_US.UTF-8 by default

# Install language pack
RUN apk --no-cache add ca-certificates wget && \
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-bin-2.25-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-i18n-2.25-r0.apk && \
    apk add glibc-bin-2.25-r0.apk glibc-i18n-2.25-r0.apk glibc-2.25-r0.apk

# Iterate through all locale and install it
COPY ./locale.md /locale.md
RUN cat locale.md | xargs -i /usr/glibc-compat/bin/localedef -i {} -f UTF-8 {}.UTF-8

# Set the lang, you can also specify it as as environment variable through docker-compose.yml
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8\
    LC_ALL=en_US.UTF-8

# Install Jenkins slave (swarm)
ADD swarm.jar /
ADD entrypoint.sh /

ENTRYPOINT /entrypoint.sh
