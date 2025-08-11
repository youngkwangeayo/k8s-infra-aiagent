#!/bin/bash

set -e

echo "=== AWS Load Balancer Controller 설치 시작 (AWS CLI 버전) ==="

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

# 1단계: OIDC Issuer URL 가져오기
echo "1. OIDC Identity Provider 설정 중..."
OIDC_ISSUER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text)
echo "OIDC Issuer: $OIDC_ISSUER"

# OIDC Provider ARN 확인 및 생성
OIDC_ID=$(echo $OIDC_ISSUER | sed 's|https://||')
OIDC_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_ID"

# OIDC Provider 존재 확인
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC_ARN --region $AWS_REGION >/dev/null 2>&1; then
    echo "OIDC Provider가 이미 존재합니다: $OIDC_ARN"
else
    echo "OIDC Provider 생성 중..."
    # OIDC Provider 생성
    aws iam create-open-id-connect-provider \
        --url $OIDC_ISSUER \
        --thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280 \
        --client-id-list sts.amazonaws.com \
        --region $AWS_REGION
    echo "✅ OIDC Provider 생성 완료"
fi

echo ""

# 2단계: IAM 정책 다운로드 및 생성
echo "2. IAM 정책 다운로드 및 생성 중..."
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/$ALB_CONTROLLER_VERSION/docs/install/iam_policy.json

# 정책 존재 확인 후 생성
if aws iam get-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --region $AWS_REGION >/dev/null 2>&1; then
    echo "IAM 정책이 이미 존재합니다."
else
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam-policy.json \
        --region $AWS_REGION
    echo "✅ IAM 정책 생성 완료"
fi

rm -f iam-policy.json
echo ""

# 3단계: Trust Policy 생성
echo "3. IAM Role 및 ServiceAccount 생성 중..."
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "$OIDC_ARN"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "$OIDC_ID:sub": "system:serviceaccount:$NAMESPACE:aws-load-balancer-controller",
                    "$OIDC_ID:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# IAM Role 생성
ROLE_NAME="AmazonEKSLoadBalancerControllerRole"
if aws iam get-role --role-name $ROLE_NAME --region $AWS_REGION >/dev/null 2>&1; then
    echo "IAM Role이 이미 존재합니다: $ROLE_NAME"
else
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file://trust-policy.json \
        --region $AWS_REGION
    echo "✅ IAM Role 생성 완료"
fi

# Policy Attach
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --role-name $ROLE_NAME \
    --region $AWS_REGION

rm -f trust-policy.json

# ServiceAccount 생성
kubectl create serviceaccount aws-load-balancer-controller -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# ServiceAccount에 Role ARN Annotation 추가
kubectl annotate serviceaccount aws-load-balancer-controller \
    -n $NAMESPACE \
    eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME \
    --overwrite

echo "✅ ServiceAccount 생성 및 설정 완료"
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
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n $NAMESPACE \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID

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