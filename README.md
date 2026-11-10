# Jenkins Infrastructure Cron Jobs

This repository holds a set of recurring ("cron-like") tasks for the Jenkins Infrastructure.
Each branch hosts an infra.ci.jenkins.io (private controller) pipeline job implementing a single task.


Details in https://github.com/jenkins-infra/helpdesk/issues/4876 for the initialization.

Cron jobs:
- [geoipupdates](https://github.com/jenkins-infra/infra-cronjobs/tree/geoipupdates): update GeoIP database used by get.jenkins.io and mirrors.updates.jenkins.io webservices
- [maven-cacher](https://github.com/jenkins-infra/infra-cronjobs/tree/maven-cacher): update Maven cache archive used by *.ci.jenkins.io agents
