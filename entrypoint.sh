#!/bin/bash

set -o pipefail

start() {
        local clientPath=$1
        local pswd=$JENKINS_MASTER_PASSWORD
        unset JENKINS_MASTER_PASSWORD

        java -jar $clientPath \
            -retry 5 \
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

# Swarm file source url
swarmUrl="$JENKINS_MASTER_URL/swarm/swarm-client.jar"

# Time variables
startTime=$(date +%s)
period=6

# State of swarm file (0 is OK, 1 is NOK)
success=1

# Attempt timeout with message
attemptTimeout() {
  # local timeout "$1" echo "One more attempt in $1 seconds"
  sleep "$1"
  echo "One more attempt in $1 seconds"
}

# Connection cycle with duration SWARM_RESPONSE_TIMEOUT and specified period
while [ $(( startTime + SWARM_RESPONSE_TIMEOUT )) -gt "$(date +%s)" ]; do

  # Establish connection with master Swarm
  echo -e "\nRequesting connection with master:"
  responseStatus=$( curl --silent --head "$swarmUrl" | grep -i "HTTP.\+\d\{3\}" | grep -o "\d\d\d.\+\S" 2> >(tee /dev/null) )
  responseStatusCode=$(grep -o "\d\d\d" <<< "$responseStatus")
  echo -e "'$swarmUrl' response is '$responseStatus'"

  if [ -n "$responseStatusCode" ] && [ "$responseStatusCode" -eq 200 ]; then

    # Request from master version of Swarm plugin
    echo -e "\nRequesting master swarm plugin version:"
    masterSwarmVersion=$(curl --silent --fail-with-body --user "$JENKINS_MASTER_USERNAME":"$pswd" "$JENKINS_MASTER_URL/pluginManager/api/xml?depth=1&xpath=//plugin\[shortName\[text()='swarm'\]\]/version" | sed 's/<version>\(.*\)<\/version>/\1/' )
    masterSwarmResponse=$?
    # Check response state
    if [ "$masterSwarmResponse" -eq 0 ]; then
      echo "Master swarm plugin version is $masterSwarmVersion"
    else
      echo "Can't determine master swarm plugin version"
      attemptTimeout $period
      continue
    fi

    # Set swarm file path
    swarmPath="/tmp/swarm-client-$masterSwarmVersion.jar"


    # Check if swarm file exists and has a non-zero size
    echo -e "\nChecking swarm file size and existence:"
    if [ -s "$swarmPath" ]; then
      echo -e "File '$swarmPath' of non-zero size was found"
      success=0
      break
    else
      echo "Swarm file was not found"
    fi

    # Download swarm-client file from master
    echo -e "\nDownloading swarm file:"
    downloadError=$( curl --fail-with-body -L "$swarmUrl" --output "$swarmPath" 2> >(tee /dev/stderr) )
    downloadStatus=$?
    # Check download response state
    if [ "$downloadStatus" -eq 0 ]; then
      echo -e "'$swarmPath' file was successfully downloaded"
    else
      echo -e "'$swarmPath' file not downloaded.\nCurl exit code ($downloadStatus)\nCurl error:\n$downloadError"
      attemptTimeout $period
      continue
    fi

    # Check downloaded file size and existence
    echo -e "\nChecking downloaded swarm file size and existence:"
    if [ -s "$swarmPath" ]; then
      echo -e "File '$swarmPath' of non-zero size was found"
      success=0
      break
    else
      echo -e "There is no swarm file or it's size equal 0"
      attemptTimeout $period
      continue
    fi

  else
    attemptTimeout $period
  fi
done

if [ "$success" -eq 0 ]; then
  echo -e "\n\tStarting Swarm:\n"

  # Starting swarm-client
  swarmMessage=$( start "$swarmPath" 2> >(tee /dev/stderr) )
  swarmStatus=$?
  if [ "$swarmStatus" -ne 0 ]; then
    echo -e "Swarm client error code '$swarmStatus':\n$swarmMessage"
    sleep $period
    exit 1
  fi

  if [ "$AVD_PID" ]; then
    kill "$SOCAT_PID"
  fi

else
  echo -e "\nErrors occurred on preparing steps:" 2> >(tee /dev/stderr)
  if [ -n "$responseStatusCode" ] && [ "$responseStatusCode" -ne 200 ]; then
    echo -e "Swarm url response error:\n\t$responseStatus" 2> >(tee /dev/stderr)
  fi

  if [ -n "$masterSwarmResponse" ]; then
    echo -e "Master swarm plugin version request failed:\n\t$masterSwarmVersion" 2> >(tee /dev/stderr)
  fi

  if [ -n "$downloadError" ]; then
    echo -e "Download error ($downloadStatus):\n\t$downloadError" 2> >(tee /dev/stderr)
  fi

  if [ -n "$fileStatus" ]; then
    echo -e "File state error:\n\t$fileStatus" 2> >(tee /dev/stderr)
  fi
  echo "---"

  # Clear all occurrences of swarm client file by name pattern
  echo -e "\n*********** Removing all swarm-client*.jar files ***********"
  find . -name "swarm-client*.jar" -exec rm -fv {} \;
  exit 1
fi
