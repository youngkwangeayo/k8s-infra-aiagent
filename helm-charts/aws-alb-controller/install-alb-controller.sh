#!/bin/bash

set -e

echo "=== AWS Load Balancer Controller 설치 시작 (AWS CLI 버전) ==="

# --- 주의 --- 
#클러스터 이동후 사용
# 변수 설정 - 환경에 따라 수정 필요
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(basename "$CURRENT_CONTEXT")  # EKS 클러스터 이름
AWS_REGION=$(aws configure get region)     # AWS 리전
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)   # AWS 계정 ID
NAMESPACE="kube-system"         # ALB Controller 설치 네임스페이스

echo "클러스터: $CLUSTER_NAME"
echo "리전: $AWS_REGION"
echo "계정 ID: $AWS_ACCOUNT_ID"
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
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.4/docs/install/iam_policy.json

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
ROLE_NAME="EKSLoadBalancerControllerRole-$CLUSTER_NAME" # IAM Role 이름 (환경별로 변경 가능)


echo "roll_name = $ROLE_NAME";

if aws iam get-role --role-name $ROLE_NAME --region $AWS_REGION >/dev/null 2>&1; then
    echo "IAM Role이 이미 존재합니다: $ROLE_NAME"
    # 기존 Role의 Trust Policy를 현재 클러스터 OIDC로 업데이트
    echo "Trust Policy를 현재 클러스터 OIDC로 업데이트 중..."
    aws iam update-assume-role-policy \
        --role-name $ROLE_NAME \
        --policy-document file://trust-policy.json
    echo "✅ Trust Policy 업데이트 완료"
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

echo "✅ AWS Load Balancer Controller 설치 완료"
echo ""



kubectl annotate serviceaccount aws-load-balancer-controller \
    -n $NAMESPACE \
    eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME \
    --overwrite


echo "ALB Controller를 재시작하여 새로운 IAM 권한을 적용합니다..."
sleep 3
# ALB Controller 재시작하여 새로운 IAM 권한 적용
kubectl rollout restart deployment/aws-load-balancer-controller -n $NAMESPACE


