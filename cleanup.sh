#!/bin/bash
echo "Starter opprydding..."

# Fjern avsluttede containere
echo "Fjerner avsluttede Docker-containere..."
docker system prune -f

# Fjern ubrukte Kubernetes-ressurser
echo "Fjerner feilede Kubernetes-poder..."
kubectl get pods -n elbatt --field-selector=status.phase=Failed -o name | xargs -r kubectl delete -n elbatt pod

# Fjern gamle Docker-images
echo "Fjerner ubrukte Docker-images..."
docker image prune -f

# Rydd opp i gamle ReplicaSets
echo "Rydder opp i gamle ReplicaSets..."
kubectl get replicasets -n elbatt | grep "0         0         0" | awk '{print $1}' | xargs -r kubectl delete replicaset -n elbatt

echo "Opprydding fullført!"
