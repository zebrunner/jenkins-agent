# Jenkins slave based on Ubuntu 16.04
## Overview
This is official [qps-infra](https://github.com/qaprosoft/qps-infra) slave image. 

## Example

Declare for each slave machine any number of labelled slaves
### Jenkins master variables ([variables.env](https://github.com/qaprosoft/qps-infra/blob/7d59b4c6f3854a04baf2884756498822dd39ec37/variables.env.original#L87))
```
# JENKINS SLAVE
JENKINS_MASTER_USERNAME=admin
JENKINS_MASTER_PASSWORD=changeit
JENKINS_MASTER_URL=http://jenkins-master:8080/jenkins
```
### Docker composer declaration
```
  jenkins-slave:
    image: qaprosoft/jenkins-slave
    env_file:
     - variables.env
    environment:
     - JENKINS_SLAVE_NAME=jenkins-slave
     - JENKINS_SLAVE_WORKERS=5
     - JENKINS_SLAVE_LABELS=qps-slave api web qa
    volumes:
     - $HOME/.ssh:/root/.ssh
     - $HOME/.m2:/root/.m2
    ports:
     - "8001:8000"
    restart: always
```
For detailes visit https://github.com/qaprosoft/qps-infra/blob/7d59b4c6f3854a04baf2884756498822dd39ec37/docker-compose.yml#L63

# Advanced options

## Setting up master Jenkins

* Install the [Swarm Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Swarm+Plugin).
* Make sure that port 50000 of master will be accessible for this slave.
* [optional] Create separate account and allow it to create slaves or just use your account.
