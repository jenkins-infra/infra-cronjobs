def archiveName = "maven-cache.tar.zst"

def storages = [
  's3-ci-jenkins-io': [
    bucketName: 'ci-jenkins-io-maven-cache',
    credentialsId: 'infra-ci-maven-cacher',
  ],
  'fs-cache-east-us-2': [
    fileshare: 'cache-east-us-2',
    storageAccount: 'cacheeastus2',
    credentialsId: 'cache-east-us-2-fileshare-serviceprincipal-writer',
  ],
  'fs-cache-sweden-central': [
    fileshare: 'cache-sweden-central',
    storageAccount: 'cacheswedencentral',
    credentialsId: 'cache-sweden-central-fileshare-serviceprincipal-writer',
  ],
]
// Region of infra.ci.jenkins.io agents
def archiveSourceStorage = storages['fs-cache-east-us-2']

properties([
  buildDiscarder(logRotator(numToKeepStr: '5')),
  pipelineTriggers([cron('0 0 * * 0')])
])

node('linux') {
  withEnv(["ARCHIVE_NAME=${archiveName}"]) {
    stage('Checkout and checks') {
      checkout scm
      sh 'tar --version'
      sh 'zstd --version'
      sh 'azcopy --version'
      sh 'aws --version'
    }

    // TODO: remove when all our agents will have this archive content copied over in their setup (cloud-init/pod template)
    stage('Retrieve existing cache') {
      withEnv([
        "STORAGE_NAME=${archiveSourceStorage.storageAccount}",
        "STORAGE_FILESHARE=${archiveSourceStorage.fileshare}",
      ]) {
        withCredentials([
          azureServicePrincipal(
            credentialsId: archiveSourceStorage.credentialsId,
            clientIdVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_ID',
            clientSecretVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_SECRET',
            subscriptionIdVariable: 'JENKINS_INFRA_SUBSCRIPTION_ID',
            tenantIdVariable: 'JENKINS_INFRA_FILESHARE_TENANT_ID',
          ),
        ]) {
          try {
            sh 'bash ./download-from-fileshare.sh'
            sh '''
            mkdir -p "${HOME}/.m2/repository"
            time tar xf "${ARCHIVE_NAME}" -C "${HOME}/.m2/repository"
            rm -f "${ARCHIVE_NAME}"
            du -sh "${HOME}/.m2/repository"
            '''
          } catch (e) {
            catchError(buildResult: 'SUCCESS', stageResult: 'NOT_BUILT') {
              error("No existing ${archiveName} found in ${archiveSourceStorage.storageAccount}/${archiveSourceStorage.fileshare}" + "\n" + e)
            }
            return
          }
        }
      }
    }

    stage('Prepare archive') {
      sh 'bash ./maven-cacher.sh'
    }

    stage('Check archive') {
      sh '''
      if ! tar --list --file "${ARCHIVE_NAME}"; then
        echo 'ERROR: invalid archive'
        exit 1
      fi
      '''
    }

    stage('Upload archive') {
      def branches = [:]

      storages.each { storageName, storage ->
        branches[storageName] = {
          stage(storageName) {
            if (storage.fileshare) {
              withEnv([
                "STORAGE_NAME=${storage.storageAccount}",
                "STORAGE_FILESHARE=${storage.fileshare}",
              ]) {
                withCredentials([
                  azureServicePrincipal(
                    credentialsId: storage.credentialsId,
                    clientIdVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_ID',
                    clientSecretVariable: 'JENKINS_INFRA_FILESHARE_CLIENT_SECRET',
                    subscriptionIdVariable: 'JENKINS_INFRA_SUBSCRIPTION_ID',
                    tenantIdVariable: 'JENKINS_INFRA_FILESHARE_TENANT_ID',
                  ),
                ]) {
                  sh 'bash ./upload-to-fileshare.sh'
                }
              }
            } else {
              withEnv(["BUCKET_NAME=${storage.bucketName}"]) {
                withCredentials([aws(credentialsId: storage.credentialsId)]) {
                  sh 'bash ./upload-to-s3.sh'
                }
              }
            }
          }
        }
      }

      parallel branches
    }

    // Set build description
    def archiveSize = readFile("${archiveName}.size").trim()
    def archiveFileCount = readFile("${archiveName}.files").trim()
    def archiveFolderCount = readFile("${archiveName}.folders").trim()
    def description = (currentBuild.description ? currentBuild.description + ' - ' : '') + "${archiveName}: ${archiveSize}, ${archiveFileCount} files in ${archiveFolderCount} folders"
    currentBuild.description = description
  }
}
