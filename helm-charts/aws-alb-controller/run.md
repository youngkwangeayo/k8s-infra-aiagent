


```bash

helm repo add eks https://aws.github.io/eks-charts
helm repo update


# values 헬름으로 구성
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n dev-aiagent \
    -f aws-alb-controller/values-dev.yaml


# CI/CD
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n $ENV-aiagent \
    -f aws-alb-controller/values-$ENV.yaml


# _미사용_ 에전 sh 로 구성 예시임
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n $NAMESPACE \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID



```