#!/bin/bash
echo "Ressursbruk for elbatt namespace:"
kubectl top pods -n elbatt
echo ""
echo "Node-status:"
kubectl get nodes -o wide
echo ""
echo "Ressursallokering:"
kubectl describe nodes | grep -A 10 "Allocated resources"
