#!/bin/bash

set -e

echo "=== AWS Load Balancer Controller 설치 시작 ==="

# 변수 설정
CLUSTER_NAME="dev-aiagent-eks-new-2"
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID="365485194891"
ALB_CONTROLLER_VERSION="v2.13.4"
NAMESPACE="kube-system"

echo "클러스터: $CLUSTER_NAME"
echo "리전: $AWS_REGION"
echo "계정 ID: $AWS_ACCOUNT_ID"
echo "ALB Controller 버전: $ALB_CONTROLLER_VERSION"
echo ""

# 1단계: IAM OIDC Identity Provider 생성
echo "1. IAM OIDC Identity Provider 생성 중..."
eksctl utils associate-iam-oidc-provider \
    --region=$AWS_REGION \
    --cluster=$CLUSTER_NAME \
    --approve

echo "✅ IAM OIDC Identity Provider 생성 완료"
echo ""

# 2단계: IAM 정책 다운로드 및 생성
echo "2. IAM 정책 다운로드 및 생성 중..."
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/$ALB_CONTROLLER_VERSION/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json \
    --region=$AWS_REGION || echo "정책이 이미 존재하거나 생성에 실패했습니다."

rm -f iam-policy.json

echo "✅ IAM 정책 생성 완료"
echo ""

# 3단계: ServiceAccount 생성
echo "3. ServiceAccount 생성 중..."
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=$NAMESPACE \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region=$AWS_REGION \
    --approve

echo "✅ ServiceAccount 생성 완료"
echo ""

# 4단계: Helm 설치 확인
echo "4. Helm 설치 확인 중..."
if ! command -v helm &> /dev/null; then
    echo "Helm이 설치되어 있지 않습니다. Helm을 설치해주세요."
    exit 1
fi

echo "✅ Helm 설치 확인 완료"
echo ""

# 5단계: EKS Chart Repository 추가
echo "5. EKS Chart Repository 추가 중..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "✅ EKS Chart Repository 추가 완료"
echo ""

# 6단계: AWS Load Balancer Controller 설치
echo "6. AWS Load Balancer Controller 설치 중..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n $NAMESPACE \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

echo "✅ AWS Load Balancer Controller 설치 완료"
echo ""

# 7단계: 설치 확인
echo "7. 설치 확인 중..."
sleep 30

kubectl get deployment -n $NAMESPACE aws-load-balancer-controller
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=aws-load-balancer-controller

echo ""
echo "=== AWS Load Balancer Controller 설치 완료 ==="
echo ""
echo "다음 명령어로 상태를 확인할 수 있습니다:"
echo "kubectl get deployment -n kube-system aws-load-balancer-controller"
echo "kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller"