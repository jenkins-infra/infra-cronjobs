node('linux-amd64') {
  checkout scm

  withCredentials([
    azureServicePrincipal(clientIdVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_ID', clientSecretVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_SECRET', credentialsId: 'cronjob-datastorage-fileshare-service-principal-writer', subscriptionIdVariable: 'JENKINS_INFRA_SUBSCRIPTION_ID ', tenantIdVariable: 'JENKINS_INFRA_FILESHARE_TENANT_ID'),
    file(credentialsId: 'kubeconfig-publick8s-getjenkinsio-restarter', variable: 'KUBECONFIG_GETJENKINSIO'),
    file(credentialsId: 'kubeconfig-publick8s-updatesjenkinsio-restarter', variable: 'KUBECONFIG_UPDATESJENKINSIO'),
  ]) {
    withEnv([
      'STORAGE_NAME=datastoragejenkinsio', // Storage Account
      'STORAGE_FILESHARE=data-storage-jenkins-io', // Fileshare
      'GEOIPUPDATE_DB_GETJIO_PROD_DIR=get.jenkins.io/geoipdata', // No slash at the beginning (fileshare signed URL has a trailing slash)
      'GEOIPUPDATE_DB_UPDATESJIO_PROD_DIR=updates.jenkins.io/geoipdata', // No slash at the beginning (fileshare signed URL has a trailing slash)
      "GEOIPUPDATE_DB_DIR=${env.WORKSPACE}/geoipdata",
    ]) {

      stage('Check Prerequisites') {
        sh '''
        docker run --rm --entrypoint=geoipupdate ghcr.io/maxmind/geoipupdate --version
        azcopy --version
        rsync --version
        '''
      }

      stage('Retrieve Current Production GeoIP DB') {
        sh '''
        bash ./retrieve-prod-geoip-db.sh
        '''
      }
    }
  }
}
