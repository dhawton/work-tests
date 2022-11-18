# Work Tests

This is a collection of tests that I have written for work.

Many of these are demos or quick prototypes to enable me to learn new tech, test ideas, or troubleshoot issues and are here for reference.

## Tests

### gke-istio-argo

This is a demo of using Argo to deploy cert-manager and Istio to a GKE cluster using the app-of-apps pattern. It can also be used to demonstrate
installation and maintenance of Istio via ArgoCD and is not restricted to just GKE.

**Note:** This may have settings atypical for a production environment as I may be using it to test various features. For example, when this README was created, the configuration is setup to enable the experimental HBONE feature for Sidecars and Ingress in version 1.16.0 of Istio.