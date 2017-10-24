FROM qaprosoft/adb-java

ENV JENKINS_SLAVE_ROOT="/opt/jenkins"

USER root

# Install some useful but optional packages
RUN apk update \
 && apk add socat bash git maven \
 && rm -rf /var/lib/apt/lists /var/cache/apt

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

# Install Jenkins slave (swarm)
ADD swarm.jar /
ADD entrypoint.sh /


ENTRYPOINT /entrypoint.sh
