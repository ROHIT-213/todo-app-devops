#!/bin/bash
# Install ArgoCD on EKS cluster

set -e

echo "Installing ArgoCD..."

# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create namespace
kubectl create namespace argocd || true

# Install ArgoCD using Helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=LoadBalancer \
  --set server.insecure=true \
  --set redis.enabled=true \
  --set applicationSet.enabled=true \
  --set notifications.enabled=true \
  --wait

echo "ArgoCD installed successfully!"

# Get initial admin password
echo ""
echo "ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

echo ""
echo "To access ArgoCD:"
echo "1. Port forward to the service:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "2. Open in browser: https://localhost:8080"
echo "   Username: admin"
echo "   Password: (from above)"

# "browserslist": {
#   "production": [
#     ">0.2%",
#     "not dead",
#     "not op_mini all"
#   ],
#   "development": [
#     "last 1 chrome version",
#     "last 1 firefox version",
#     "last 1 safari version"
#   ]
# }
