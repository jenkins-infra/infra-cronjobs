node('linux-amd64') {
  checkout scm

  withEnv([
    'STORAGE_NAME=datastoragejenkinsio', // Storage Account
    'STORAGE_FILESHARE=data-storage-jenkins-io', // Fileshare
    'GEOIPUPDATE_DB_GETJIO_PROD_DIR=get.jenkins.io/geoipdata', // No slash at the beginning (signed URL has a trailing slash)
    'GEOIPUPDATE_DB_UPDATESJIO_PROD_DIR=updates.jenkins.io/geoipdata', // No slash at the beginning (signed URL has a trailing slash)
    "GEOIPUPDATE_DB_DIR=${env.WORKSPACE}/geoipdata",
    'GEOIPUPDATE_DOCKER_IMAGE=ghcr.io/maxmind/geoipupdate:v8.0.0', // Tracked by updatecli
  ]) {

    stage('Check Prerequisites') {
      sh '''
      docker run --rm --entrypoint=geoipupdate "${GEOIPUPDATE_DOCKER_IMAGE}" --version
      azcopy --version
      rsync --version
      '''
    }

    stage('Retrieve Current Production GeoIP DB') {
      withCredentials([
        azureServicePrincipal(clientIdVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_ID', clientSecretVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_SECRET', credentialsId: 'cronjob-datastorage-fileshare-service-principal-writer', subscriptionIdVariable: 'JENKINS_INFRA_SUBSCRIPTION_ID ', tenantIdVariable: 'JENKINS_INFRA_FILESHARE_TENANT_ID'),
      ]) {
        sh '''
        bash ./retrieve-prod-geoip-db.sh
        '''
      }
    }

    stage('Get latest Maxmind GeoIP DB') {
      withEnv([
        'GEOIPUPDATE_DRYRUN=false', // set to true for production
        'GEOIPUPDATE_EDITION_IDS=GeoLite2-ASN GeoLite2-City GeoLite2-Country', // ref. https://github.com/maxmind/geoipupdate/blob/main/doc/docker.md#configuring
      ]) {
        withCredentials([
          string(credentialsId: 'geoipupdate_account_id', variable: 'GEOIPUPDATE_ACCOUNT_ID'), // ref. https://github.com/maxmind/geoipupdate/blob/main/doc/docker.md#configuring
          string(credentialsId: 'geoipupdate_license_key', variable: 'GEOIPUPDATE_LICENSE_KEY'), // ref. https://github.com/maxmind/geoipupdate/blob/main/doc/docker.md#configuring
        ]) {
          sh '''
          bash ./get-maxmind-geoip-db.sh
          '''
        }
      }
    }

    stage('Update Production GeoIP DB') {
      withCredentials([
        file(credentialsId: 'kubeconfig-publick8s-getjenkinsio-restarter', variable: 'KUBECONFIG_GETJENKINSIO'),
        file(credentialsId: 'kubeconfig-publick8s-updatesjenkinsio-restarter', variable: 'KUBECONFIG_UPDATESJENKINSIO'),
      ]) {
        sh '''
        echo DEPLOY
        '''
      }
    }
  }
}
