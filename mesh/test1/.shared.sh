#!/bin/bash

function install_istio() {
  CLUSTER_NAME=$1

  echo "Installing istio to cluster $CLUSTER_NAME"

  cat << EOF | istioctl install -y --context $CLUSTER_NAME -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: gloo-mesh-istio
  namespace: istio-system
spec:
  # only the control plane components are installed (https://istio.io/latest/docs/setup/additional-setup/config-profiles/)
  profile: minimal
  # Solo.io Istio distribution repository
  hub: gcr.io/istio-enterprise
  # Solo.io Gloo Mesh Istio tag
  tag: ${ISTIO_VERSION}

  meshConfig:
    # enable access logging to standard output
    accessLogFile: /dev/stdout

    defaultConfig:
      # wait for the istio-proxy to start before application pods
      holdApplicationUntilProxyStarts: true
      # enable Gloo Mesh metrics service (required for Gloo Mesh Dashboard)
      envoyMetricsService:
        address: enterprise-agent.gloo-mesh:9977
      # enable GlooMesh accesslog service (required for Gloo Mesh Access Logging)
      envoyAccessLogService:
        address: enterprise-agent.gloo-mesh:9977
      proxyMetadata:
        # Enable Istio agent to handle DNS requests for known hosts
        # Unknown hosts will automatically be resolved using upstream dns servers in resolv.conf
        # (for proxy-dns)
        ISTIO_META_DNS_CAPTURE: "true"
        # Enable automatic address allocation (for proxy-dns)
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
        # Used for gloo mesh metrics aggregation
        # should match trustDomain (required for Gloo Mesh Dashboard)
        GLOO_MESH_CLUSTER_NAME: ${CLUSTER_NAME}

    # Set the default behavior of the sidecar for handling outbound traffic from the application.
    outboundTrafficPolicy:
      mode: ALLOW_ANY
    # The trust domain corresponds to the trust root of a system. 
    # For Gloo Mesh this should be the name of the cluster that cooresponds with the CA certificate CommonName identity
    trustDomain: ${CLUSTER_NAME}
  components:
    ingressGateways:
    # enable the default ingress gateway
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: LoadBalancer
          ports:
            # health check port (required to be first for aws elbs)
            - name: status-port
              port: 15021
              targetPort: 15021
            # main http ingress port
            - port: 80
              targetPort: 8080
              name: http2
            # main https ingress port
            - port: 443
              targetPort: 8443
              name: https
            # Port for gloo-mesh multi-cluster mTLS passthrough (Required for Gloo Mesh east/west routing)
            - port: 15443
              targetPort: 15443
              # Gloo Mesh looks for this default name 'tls' on an ingress gateway
              name: tls
    pilot:
      k8s:
        env:
        # Allow multiple trust domains (Required for Gloo Mesh east/west routing)
          - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
            value: "true"
  values:
    # https://istio.io/v1.5/docs/reference/config/installation-options/#global-options
    global:
      # needed for connecting VirtualMachines to the mesh
      network: ${CLUSTER_NAME}
      # needed for annotating istio metrics with cluster (should match trust domain and GLOO_MESH_CLUSTER_NAME)
      multiCluster:
        clusterName: ${CLUSTER_NAME}
EOF
  check_fail $? "istioctl install failed"
}

function register_remote_cluster() {
  echo "Registering remote cluster $2"
  mgmt_context=$1
  remote_context=$2
  echo " - Finding management plane external address and port"
  ent_ip=$(kubectl get svc -n gloo-mesh enterprise-networking --context $mgmt_context -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  ent_port=$(kubectl get svc -n gloo-mesh enterprise-networking --context $mgmt_context -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
  ent_addr="${ent_ip}:${ent_port}"

  echo " - Registering with management plane"
  meshctl cluster register enterprise --mgmt-context=$mgmt_context --remote-context=$remote_context --relay-server-address $ent_addr $remote_context
  echo "Done"
}

function verify_registered {
  echo "Verifying remote cluster $2 is registered"
  mgmt_context=$1
  remote_context=$2
  while true; do
    kubectl get kubernetescluster -n gloo-mesh --context $mgmt_context | grep $remote_context
    if [ $? -eq 0 ]; then
      echo "Remote cluster $remote_context is registered"
      break
    fi
    echo " - Remote cluster $remote_context is not registered yet"
    sleep 5
  done

  echo "Verify istio has been discovered"
  while true; do
    kubectl get mesh -n gloo-mesh --context $mgmt_context | grep "istiod-istio-system-${remote_context}"
    if [ $? -eq 0 ]; then
      echo "Istio has been discovered"
      break
    fi
    echo " - Istio has not been discovered yet"
    sleep 5
  done
}

function create_virtual_mesh() {
  mgmt_context=$1
  shift
  remote_contexts=("$@")

  echo "Creating virtual mesh"
  echo " - Creating yaml"
  cat >.tmp.virtualmesh.yaml <<EOF
apiVersion: networking.mesh.gloo.solo.io/v1
kind: VirtualMesh
metadata:
  name: virtual-mesh
  namespace: gloo-mesh
spec:
  mtlsConfig:
    # Note: Do NOT use this autoRestartPods setting in production!!
    autoRestartPods: true
    # automatically generate CA certificates for istiod deployments
    shared:
      rootCertificateAuthority:
        generated: {}
  federation:
    # federate all Destinations to all external meshes
    selectors:
    - {}
  # Disable global access policy enforcement for demonstration purposes.
  globalAccessPolicy: DISABLED
  meshes:
EOF
  for ctx in "${remote_contexts[@]}"; do
    echo "  - name: istiod-istio-system-${ctx}" >> .tmp.virtualmesh.yaml
    echo "    namespace: gloo-mesh" >> .tmp.virtualmesh.yaml
  done
  echo " - Applying yaml"
  kubectl apply -f .tmp.virtualmesh.yaml --context $mgmt_context
  rm .tmp.virtualmesh.yaml
  echo "Created."
  echo "Waiting for each to be accepted"
  for ctx in "${remote_contexts[@]}"; do
    while true; do
      echo " - Checking for $ctx"
      ctxstatus=$(kubectl get virtualmesh -n gloo-mesh virtual-mesh --context ${mgmt_context} -o json | jq -r ".status.meshes[\"istiod-istio-system-${ctx}.gloo-mesh.\"].state")
      if [[ "$ctxstatus" == "ACCEPTED" ]]; then
        echo "   - VirtualMesh istiod-istio-system-${ctx} is accepted"
        break
      fi
      echo "    - Current state is: $ctxstatus"
      sleep 5
    done
  done
  echo "Virtual Mesh created and accepted"
}

function wait_for_pod_ready() {
  context=$1
  namespace=$2

  echo "Waiting for all pods in namespace $namespace to be ready"
  while true; do
    ready=$(kubectl get pods --context $context -n $namespace -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{" "}{.metadata.name}{"\n"}{end}' | grep -v "False" | wc -l)
    total=$(kubectl get pods --context $context -n $namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | wc -l)
    if [[ "$ready" == "$total" ]]; then
      echo "All pods in namespace $namespace are ready"
      break
    fi
    sleep 5
  done
}

function check_fail() {
  if [ $1 -ne 0 ]; then
    echo "Failed: $2"
    exit 1
  fi
}