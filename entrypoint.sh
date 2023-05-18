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

ERROR="\033[0;31m"
SUCCESS="\033[0;32m"
HEADER="\033[0;36m"
ATTENTION="\033[0;33m"
RESET="\033[0m"

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
  echo -e "${HEADER}Requesting $swarmPath:${RESET}"
  responseStatus=$( curl --silent --head $swarmUrl | grep -i "HTTP.\+\d\{3\}" | grep -o "\d\d\d.\+\S" )
  responseStatusCode=$(grep -o "\d\d\d" <<< "$responseStatus")
  if [ $responseStatusCode -eq 200 ]; then
    echo -e "${SUCCESS}'$swarmUrl' response is '$responseStatus'${RESET}"

    echo -e "${HEADER}Downloading $swarmPath:${RESET}"
    downloadError=$( curl -L $swarmUrl --output $swarmPath 2> >(tee /dev/stderr) )
    downloadStatus=$?
    if [ "$downloadStatus" -eq 0 ]; then
      echo -e "${SUCCESS}'$swarmPath' file was successfully downloaded${RESET}"
    else
      echo -e "${ERROR}'$swarmPath' file not downloaded.\nCurl exit code ($downloadStatus)\nCurl error:\n$downloadError${RESET}"
      attemptTimeout
      continue
    fi

    echo -e "${HEADER}Checking $swarmPath size and existence:${RESET}"
    test -s $swarmPath
    fileStatus=$?
    if [ $fileStatus -eq 0 ]; then
      echo -e "${SUCCESS}'$swarmPath' file was successfully found${RESET}"
      success=0
      break
    else
      echo -e "${ERROR}There is no file '$swarmPath' or it's size equal 0${RESET}"
      attemptTimeout
      continue
    fi
  else
    echo -e "${ERROR}'$swarmUrl' response '$responseStatus'${RESET}"
    attemptTimeout
  fi
done

if [ "$success" -eq 0 ]; then
  echo -e "${HEADER}Starting $swarmPath:${RESET}"

  swarmMessage=$( start 2> >(tee /dev/stderr) )
  swarmStatus=$?
  echo $swarmMessage
  if [ "$swarmStatus" -ne 0 ]; then
    echo -e "${ATTENTION}\nErrors occurred on swarm start:${RESET}" 2> >(tee /dev/stderr)
    echo -e "${ERROR}Error code ($swarmStatus):\n\t$swarmMessage${RESET}" 2> >(tee /dev/stderr)

    sleep $period
    exit 1
  fi

  if [ "$AVD_PID" ]; then
    kill "$SOCAT_PID"
  fi

else
  echo -e "${ATTENTION}\nErrors occurred on preparing steps:${RESET}" 2> >(tee /dev/stderr)
  if [ "$responseStatusCode" -ne 200 ]; then
    echo -e "${ERROR}Swarm url response error:\n\t$responseStatus${RESET}" 2> >(tee /dev/stderr)
  fi

  if [ ! -z $downloadError ]; then
    echo -e "${ERROR}Download error ($downloadStatus):\n\t$downloadError${RESET}" 2> >(tee /dev/stderr)
  fi

  if [ ! -z $fileStatus ]; then
    echo -e "${ERROR}File state error:\n\t$fileStatus${RESET}" 2> >(tee /dev/stderr)
  fi

  exit 1
fi
