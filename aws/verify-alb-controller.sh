#!/bin/bash

set -e

echo "=== AWS Load Balancer Controller 상태 확인 ==="
echo ""

# 1단계: Deployment 상태 확인
echo "1. Deployment 상태 확인:"
kubectl get deployment -n kube-system aws-load-balancer-controller

echo ""

# 2단계: Pod 상태 확인
echo "2. Pod 상태 확인:"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo ""

# 3단계: ServiceAccount 확인
echo "3. ServiceAccount 확인:"
kubectl get serviceaccount -n kube-system aws-load-balancer-controller

echo ""

# 4단계: 로그 확인 (최근 20줄)
echo "4. Controller 로그 (최근 20줄):"
kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller --tail=20

echo ""

# 5단계: IngressClass 확인
echo "5. IngressClass 확인:"
kubectl get ingressclass

echo ""
echo "=== 상태 확인 완료 ==="