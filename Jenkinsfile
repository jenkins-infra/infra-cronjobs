def archiveName = "maven-cache-jenkinsci.tar.gz"

def storages = [
  'sweden-central': [
    fileshare: 'cache-cert-ci-jenkins-io',
    credentialsId: 'infraci-certcijenkinsio-fileshare-serviceprincipal-writer',
    storageAccount: 'certcijenkinsiosponsored'
  ],
]
// TODO: replace by storage account in same region as infra.ci.jenkins.io agents when ready
def archiveSourceStorage = storages['sweden-central']

properties([
  disableConcurrentBuilds(abortPrevious: true),
  buildDiscarder(logRotator(numToKeepStr: '5')),
  pipelineTriggers([cron('0 0 * * 0')])
])

node('linux-amd64') {
  stage('Checkout and checks') {
    checkout scm
    sh 'azcopy --version'
  }

  // TODO: remove when all our agents will have this archive content copied over in their setup (cloud-init/pod template)
  stage('Retrieve existing archive into Maven local cache') {
    withEnv([
      "STORAGE_NAME=${archiveSourceStorage.storageAccount}",
      "STORAGE_FILESHARE=${archiveSourceStorage.fileshare}",
      "SOURCE_PATH=${archiveName}",
      'DESTINATION_PATH=content',
      'MVN_LOCAL_REPO=${HOME}/.m2/repository',
    ]) {
      withCredentials([
        azureServicePrincipal(
          credentialsId: archiveSourceStorage.credentialsId,
          clientIdVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_ID',
          clientSecretVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_SECRET',
          subscriptionIdVariable: 'JENKINS_INFRA_SUBSCRIPTION_ID ',
          tenantIdVariable: 'JENKINS_INFRA_FILESHARE_TENANT_ID',
        ),
      ]) {
        try {
          sh 'bash ./retrieve-from-fileshare.sh'
          // TODO: extract archive
          sh '''
            ls -al "${DESTINATION_PATH}
          '''
        } catch (e) {
          catchError(buildResult: 'SUCCESS', stageResult: 'NOT_BUILT') {
            error("No existing ${archiveName} found in ${archiveSourceStorage.storageAccount}/${archiveSourceStorage.fileshare}")
          }
          return
        }
      }
    }
  }

  stage('Prepare archive') {
    withEnv([
      "MVN_ARCHIVE_NAME=${archiveName}",
      "MVN_CACHE_DIR=${env.WORKSPACE}",
    ]) {
      // Fetch the Maven settings with artifact caching proxy in a tmp folder, and set MAVEN_SETTINGS env var to its absolute location.
      sh 'bash ./maven-cacher.sh'
    }
  }

  stage('Update storages') {
    branches = storages.each { storage ->
      stage(storage) {
        if (storage.fileshare) {
          withEnv([
            "STORAGE_NAME=${storage.storageAccount}",
            "STORAGE_FILESHARE=${storage.fileshare}",
            "MVN_ARCHIVE_NAME=${archiveName}",
          ]) {
            withCredentials([
              azureServicePrincipal(
                credentialsId: storage.credentialsId,
                clientIdVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_ID',
                clientSecretVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_SECRET',
                subscriptionIdVariable: 'JENKINS_INFRA_SUBSCRIPTION_ID ',
                tenantIdVariable: 'JENKINS_INFRA_FILESHARE_TENANT_ID',
              ),
            ]) {
              echo 'No upload yet'
              sh 'env | var'
              // sh 'bash ./update-fileshare-archive.sh'
            }
          }
        } // else S3 (later)
      }
    }

    parallel branches
  }
}
