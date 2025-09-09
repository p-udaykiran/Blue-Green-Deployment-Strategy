## Create Service Account, Role, ClusterRole & Assign that role, And create a secret for Service Account and genrate a Token

### Creating Service Account


```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa
  namespace: webapps
```

### Create Role 


```yaml
apiVersion: rbac.authorization.k8s.io/v1  # This is the API version for RBAC resources
kind: Role                                # Kind 'Role' means permissions are scoped to a specific namespace
metadata:
  name: app-role                          # Name of the Role
  namespace: webapps                      # The namespace where this Role applies (webapps)
rules:
  - apiGroups:
        - ""                             # Core API group (pods, services, secrets, configmaps, etc.)
        - apps                           # API group for deployments, replicasets, statefulsets
        - autoscaling                    # For HorizontalPodAutoscalers
        - batch                          # For jobs and cronjobs
        - extensions                     # Older resources like ingress (used in some versions)
        - policy                         # PodSecurityPolicies, if used
        - rbac.authorization.k8s.io      # For roles, rolebindings, etc.
    resources:
      - pods                            # Pods in the namespace
      - secrets                         # Secrets
      - componentstatuses               # Cluster component statuses (rarely used)
      - configmaps                      # ConfigMaps
      - daemonsets                       # DaemonSets
      - deployments                      # Deployments
      - events                           # Events in the namespace
      - endpoints                        # Service endpoints
      - horizontalpodautoscalers         # HPA objects
      - ingress                          # Ingress resources
      - jobs                             # Jobs
      - limitranges                       # Resource limit definitions
      - namespaces                        # Namespace info (read-only)
      - nodes                             # Node info (read-only)
      - persistentvolumes                 # Persistent Volumes
      - persistentvolumeclaims            # PVCs
      - resourcequotas                    # Resource quotas in namespace
      - replicasets                       # ReplicaSets
      - replicationcontrollers            # ReplicationControllers
      - serviceaccounts                   # ServiceAccounts
      - services                          # Services
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] 
    # "verbs" define what actions are allowed on the resources:
    # - get: read a single object
    # - list: list all objects of this type
    # - watch: monitor for changes
    # - create: create new objects
    # - update: modify existing objects
    # - patch: partially update objects
    # - delete: remove objects

```

### Bind the role to service account


```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: webapps 
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role 
subjects:
- namespace: webapps 
  kind: ServiceAccount
  name: jenkins 
```


### Create a ClusterRole for PV access

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: persistent-volume-access
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

```

### Bind the clusterRole to Jenkins Service Account

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-persistent-volume-access
subjects:
  - kind: ServiceAccount
    name: jenkins
    namespace: webapps
roleRef:
  kind: ClusterRole
  name: persistent-volume-access
  apiGroup: rbac.authorization.k8s.io

```


### Generate token using service account in the namespace

[Create Token](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#:~:text=To%20create%20a%20non%2Dexpiring,with%20that%20generated%20token%20data.)
