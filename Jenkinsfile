pipeline {
    agent any
    
    parameters {
        choice(
            name: 'DEPLOY_ENV', 
            choices: ['blue', 'green'], 
            description: 'Select the environment for deployment: "blue" or "green".'
        )
        booleanParam(
            name: 'SWITCH_TRAFFIC', 
            defaultValue: false, 
            description: 'Check this box to switch traffic to the selected environment (Blue or Green).'
        )
    }
    
    environment {
        IMAGE_NAME = 'udaypagidimari/bankapp'
        TAG = "${params.DEPLOY_ENV}-${BUILD_NUMBER}" 
        KUBE_NAMESPACE = 'webapps'
        SCANNER_HOME = tool 'sonar-scanner'
    }
    
    stages {

        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Git Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/p-udaykiran/Blue-Green-Deployment-Strategy.git'
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-scanner') {
                    sh """
                        ${SCANNER_HOME}/bin/sonar-scanner \
                        -Dsonar.projectKey=nodejsbg \
                        -Dsonar.projectName=nodejsbg
                    """
                }
            }
        }
        
        stage('Filesystem Scan') {
            steps {
                sh "trivy fs --format table -o fs.html ."
            }
        }
        
        stage('Docker Build') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker build --no-cache -t ${IMAGE_NAME}:${TAG} ."
                    }
                }
            }
        }
        
        stage('Image Scan') {
            steps {
                sh "trivy image --format table -o image.html ${IMAGE_NAME}:${TAG}"
            }
        }
        
        stage('Docker Push') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                    }
                }
            }
        }
        
        stage('Deploy Service') {
            steps {
                withKubeConfig(
                    clusterName: 'uday-cluster',
                    credentialsId: 'k8-token',
                    namespace: "${KUBE_NAMESPACE}",
                    serverUrl: 'https://613C969F875D0F9F2896571C072850F4.gr7.ap-south-1.eks.amazonaws.com'
                ) {
                    sh """
                        if ! kubectl get svc app -n ${KUBE_NAMESPACE}; then
                            kubectl apply -f app-service.yml -n ${KUBE_NAMESPACE}
                        fi
                    """
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    def deploymentFile = (params.DEPLOY_ENV == 'blue') ? 'app-deployment-blue.yml' : 'app-deployment-green.yml'

                    withKubeConfig(
                        clusterName: 'uday-cluster', 
                        credentialsId: 'k8-token', 
                        namespace: "${KUBE_NAMESPACE}",
                        serverUrl: 'https://613C969F875D0F9F2896571C072850F4.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh """
                            sed -i 's|udaypagidimari/bankapp:.*|udaypagidimari/bankapp:${TAG}|g' ${deploymentFile}
                            kubectl apply -f pv-pvc.yml -n ${KUBE_NAMESPACE}
                            kubectl apply -f mysql-ds.yml -n ${KUBE_NAMESPACE}
                            kubectl apply -f ${deploymentFile} -n ${KUBE_NAMESPACE}
                        """
                    }
                }
            }
        }

        stage('Switch Traffic') {
            when {
                expression { params.SWITCH_TRAFFIC }
            }
            steps {
                script {
                    def newEnv = params.DEPLOY_ENV
                    withKubeConfig(
                        clusterName: 'uday-cluster',
                        credentialsId: 'k8-token',
                        namespace: "${KUBE_NAMESPACE}",
                        serverUrl: 'https://613C969F875D0F9F2896571C072850F4.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh """
                            kubectl patch service app \
                            -p '{"spec":{"selector":{"app":"app","version":"${newEnv}"}}}' \
                            -n ${KUBE_NAMESPACE}
                        """
                    }
                    echo "✅ Traffic has been switched to the ${newEnv} environment."
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    def verifyEnv = params.DEPLOY_ENV
                    withKubeConfig(
                        clusterName: 'uday-cluster',
                        credentialsId: 'k8-token',
                        namespace: "${KUBE_NAMESPACE}",
                        serverUrl: 'https://613C969F875D0F9F2896571C072850F4.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh """
                            echo "🔍 Verifying ${verifyEnv} deployment..."
                            kubectl get pods -l version=${verifyEnv} -n ${KUBE_NAMESPACE}
                            kubectl get svc app -n ${KUBE_NAMESPACE}
                        """
                    }
                }
            }
        }
    }
}
