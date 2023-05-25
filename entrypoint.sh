#!/bin/bash

start() {
        local pswd=$JENKINS_MASTER_PASSWORD
        unset JENKINS_MASTER_PASSWORD

        java -jar /swarm-client.jar \
            -username $JENKINS_MASTER_USERNAME \
            -password $pswd \
            -mode $JENKINS_SLAVE_MODE \
            -name $JENKINS_SLAVE_NAME \
            -executors $JENKINS_SLAVE_WORKERS \
            -master $JENKINS_MASTER_URL \
            -fsroot $JENKINS_SLAVE_ROOT \
            -labels "$JENKINS_SLAVE_LABELS swarm"
}


if [ "$AVD" ]; then
    socat tcp-listen:5555,bind=127.0.0.1,fork tcp:$AVD & SOCAT_PID=$!
fi

start

if [ "$AVD_PID" ]; then
    kill $SOCAT_PID
fi

