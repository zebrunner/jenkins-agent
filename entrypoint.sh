#!/bin/bash

start() {
        local pswd=$JENKINS_MASTER_PASSWORD
        unset JENKINS_MASTER_PASSWORD

        java -jar /swarm-client.jar \
            -disableClientsUniqueId \
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

swarmUrl="$JENKINS_MASTER_URL/swarm/swarm-client.jar"
swarmPath="/swarm-client.jar"

startTime=$(date +%s)
period=10
success=1

attemptTimeout() {
  echo "One more attempt in $period seconds"
  sleep $period
}

while [ $(( startTime + SWARM_RESPONSE_TIMEOUT )) -gt "$(date +%s)" ]; do
  echo -e "Requesting $swarmPath:"
  responseStatus=$( curl --silent --head $swarmUrl | grep -i "HTTP.\+\d\{3\}" | grep -o "\d\d\d.\+\S" )
  responseStatusCode=$(grep -o "\d\d\d" <<< "$responseStatus")
  if [ $responseStatusCode -eq 200 ]; then
    echo -e "'$swarmUrl' response is '$responseStatus'"

    echo -e "Downloading $swarmPath:"
    downloadError=$( curl -L $swarmUrl --output $swarmPath 2> >(tee /dev/stderr) )
    downloadStatus=$?
    if [ "$downloadStatus" -eq 0 ]; then
      echo -e "'$swarmPath' file was successfully downloaded"
    else
      echo -e "'$swarmPath' file not downloaded.\nCurl exit code ($downloadStatus)\nCurl error:\n$downloadError"
      attemptTimeout
      continue
    fi

    echo -e "Checking $swarmPath size and existence:"
    test -s $swarmPath
    fileStatus=$?
    if [ $fileStatus -eq 0 ]; then
      echo -e "'$swarmPath' file was successfully found"
      success=0
      break
    else
      echo -e "There is no file '$swarmPath' or it's size equal 0"
      attemptTimeout
      continue
    fi
  else
    echo -e "'$swarmUrl' response '$responseStatus'"
    attemptTimeout
  fi
done

if [ "$success" -eq 0 ]; then
  echo -e "Starting $swarmPath:"

  swarmMessage=$( start 2> >(tee /dev/stderr) )
  swarmStatus=$?
  echo $swarmMessage
  if [ "$swarmStatus" -ne 0 ]; then
    echo -e "\nErrors occurred on swarm start:" 2> >(tee /dev/stderr)
    echo -e "Error code ($swarmStatus):\n\t$swarmMessage" 2> >(tee /dev/stderr)

    sleep $period
    exit 1
  fi

  if [ "$AVD_PID" ]; then
    kill "$SOCAT_PID"
  fi

else
  echo -e "\nErrors occurred on preparing steps:" 2> >(tee /dev/stderr)
  if [ "$responseStatusCode" -ne 200 ]; then
    echo -e "Swarm url response error:\n\t$responseStatus" 2> >(tee /dev/stderr)
  fi

  if [ ! -z $downloadError ]; then
    echo -e "Download error ($downloadStatus):\n\t$downloadError" 2> >(tee /dev/stderr)
  fi

  if [ ! -z $fileStatus ]; then
    echo -e "File state error:\n\t$fileStatus" 2> >(tee /dev/stderr)
  fi

  exit 1
fi
