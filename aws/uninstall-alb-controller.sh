#!/bin/bash

set -e

echo "=== AWS Load Balancer Controller 제거 시작 ==="

# 변수 설정
CLUSTER_NAME="dev-aiagent-eks-new-2"
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID="365485194891"
NAMESPACE="kube-system"

echo "클러스터: $CLUSTER_NAME"
echo "리전: $AWS_REGION"
echo "계정 ID: $AWS_ACCOUNT_ID"
echo ""

# 1단계: Helm으로 AWS Load Balancer Controller 제거
echo "1. AWS Load Balancer Controller 제거 중..."
helm uninstall aws-load-balancer-controller -n $NAMESPACE || echo "Controller가 이미 제거되었거나 존재하지 않습니다."

echo "✅ AWS Load Balancer Controller 제거 완료"
echo ""

# 2단계: ServiceAccount 제거
echo "2. ServiceAccount 제거 중..."
eksctl delete iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=$NAMESPACE \
    --name=aws-load-balancer-controller \
    --region=$AWS_REGION || echo "ServiceAccount가 이미 제거되었거나 존재하지 않습니다."

echo "✅ ServiceAccount 제거 완료"
echo ""

# 3단계: IAM 정책 제거 (선택사항)
echo "3. IAM 정책 제거 여부를 확인합니다..."
read -p "IAM 정책 AWSLoadBalancerControllerIAMPolicy를 제거하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    aws iam delete-policy \
        --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
        --region=$AWS_REGION || echo "정책이 이미 제거되었거나 존재하지 않습니다."
    echo "✅ IAM 정책 제거 완료"
else
    echo "IAM 정책은 유지됩니다."
fi

echo ""

# 4단계: 제거 확인
echo "4. 제거 확인 중..."
sleep 10

echo "남은 리소스 확인:"
kubectl get deployment -n $NAMESPACE aws-load-balancer-controller 2>/dev/null || echo "✅ Deployment가 성공적으로 제거되었습니다."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=aws-load-balancer-controller 2>/dev/null || echo "✅ Pod가 성공적으로 제거되었습니다."

echo ""
echo "=== AWS Load Balancer Controller 제거 완료 ==="