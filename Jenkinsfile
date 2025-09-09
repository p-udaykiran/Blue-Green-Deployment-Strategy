pipeline {
    agent any
    
    // Parameters to choose environment and whether to switch traffic
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
    
    // Environment variables used across stages
    environment {
        IMAGE_NAME = 'udaypagidimari/bankapp'            // Docker image name
        TAG = "${params.DEPLOY_ENV}-${BUILD_NUMBER}"     // Tag includes environment + build number
        KUBE_NAMESPACE = 'webapps'                       // Kubernetes namespace
        SCANNER_HOME = tool 'sonar-scanner'             // SonarQube scanner path
    }
    
    stages {

        // Clean the Jenkins workspace before starting
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        // Checkout the Git repository
        stage('Git Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/p-udaykiran/Blue-Green-Deployment-Strategy.git'
            }
        }
        
        // Run SonarQube static code analysis
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
        
        // Scan filesystem for vulnerabilities using Trivy
        stage('Filesystem Scan') {
            steps {
                sh "trivy fs --format table -o fs.html ."
            }
        }
        
        // Build the Docker image
        stage('Docker Build') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker build --no-cache -t ${IMAGE_NAME}:${TAG} ."
                    }
                }
            }
        }
        
        // Scan the Docker image for vulnerabilities
        stage('Image Scan') {
            steps {
                sh "trivy image --format table -o image.html ${IMAGE_NAME}:${TAG}"
            }
        }
        
        // Push the Docker image to the registry
        stage('Docker Push') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                    }
                }
            }
        }
        
        // Deploy Kubernetes Service if it does not exist
        stage('Deploy Service') {
            steps {
                withKubeConfig(
                    clusterName: 'uday-cluster',
                    credentialsId: 'k8-token',
                    namespace: "${KUBE_NAMESPACE}",
                    serverUrl: 'https://613C969F875D0F9F2896571C072850F4.gr7.ap-south-1.eks.amazonaws.com'
                ) {
                    sh """
                        # Only create the service if it doesn't exist
                        if ! kubectl get svc app -n ${KUBE_NAMESPACE}; then
                            kubectl apply -f app-service.yml -n ${KUBE_NAMESPACE}
                        fi
                    """
                }
            }
        }
        
        // Deploy the selected environment (Blue or Green) to Kubernetes
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
                            # Replace image tag dynamically in deployment YAML
                            sed -i 's|udaypagidimari/bankapp:.*|udaypagidimari/bankapp:${TAG}|g' ${deploymentFile}
                            
                            # Apply PersistentVolume & PVC for MySQL
                            kubectl apply -f pv-pvc.yml -n ${KUBE_NAMESPACE}
                            
                            # Deploy MySQL StatefulSet
                            kubectl apply -f mysql-ds.yml -n ${KUBE_NAMESPACE}
                            
                            # Deploy app environment (blue or green)
                            kubectl apply -f ${deploymentFile} -n ${KUBE_NAMESPACE}
                        """
                    }
                }
            }
        }

        // Switch traffic to the selected environment (Blue/Green)
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
                            # Patch service selector to route traffic to chosen environment
                            kubectl patch service app \
                            -p '{"spec":{"selector":{"app":"app","version":"${newEnv}"}}}' \
                            -n ${KUBE_NAMESPACE}
                        """
                    }
                    echo "✅ Traffic has been switched to the ${newEnv} environment."
                }
            }
        }
        
        // Verify deployment and check pods and service status
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
                            
                            # List pods for the selected environment
                            kubectl get pods -l version=${verifyEnv} -n ${KUBE_NAMESPACE}
                            
                            # Show service details
                            kubectl get svc app -n ${KUBE_NAMESPACE}
                        """
                    }
                }
            }
        }
    }
}
