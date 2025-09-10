

```bash

#------- infra start 인프라 관리자 초기 한번만 ----- 

# 기본 네임스페이스 등록
kubectl apply -f helm-charts/namespace.yaml


# 차트 alb 추가
helm repo add eks https://aws.github.io/eks-charts

# 헬름 alb 베포
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller  \
    -n kube-system \
    -f helm-charts/aws-alb-controller/values.yaml \
    -f helm-charts/aws-alb-controller/values-dev.yaml

# aws  IAM 역할 생성 
./helm-charts/aws-alb-controller/install-alb-controller.sh


# infra 베포
helm upgrade --install infra helm-charts/infra/ -n dev-aiagent -f helm-charts/infra/values.yaml -f helm-charts/infra/values-dev.yaml

# 레디스 베포
helm upgrade --install redis helm-charts/redis/ \
     -n dev-aiagent \
     -f helm-charts/redis/values.yaml \
     -f helm-charts/redis/values-dev.yaml \

#------- infra END -----


#------- app build -------
    
 helm upgrade --install aiagent helm-charts/aiagent/ \
      -n dev-aiagent \
      -f helm-charts/aiagent/values.yaml \
      -f helm-charts/aiagent/values-dev.yaml \
      --set image.tag=0.2.97

 helm upgrade --install aiagent-api helm-charts/aiagent-api/ \
      -n dev-aiagent \
      -f helm-charts/aiagent-api/values.yaml \
      -f helm-charts/aiagent-api/values-dev.yaml \
      --set image.tag=0.1.31

 helm upgrade --install aiagent-system helm-charts/aiagent-system/ \
      -n dev-aiagent \
      -f helm-charts/aiagent-system/values.yaml \
      -f helm-charts/aiagent-system/values-dev.yaml \
      --set image.tag=0.0.91



#------- logging build -------

 helm upgrade --install logging-backend helm-charts/logging/logging-backend/ \
      -n logging \
      -f helm-charts/logging/logging-backend/values.yaml \
      -f helm-charts/logging/logging-bkuackend/values-dev.yaml \


# 헬름차트 fluent-bit 패키지 로컬에 추가
helm repo add fluent https://fluent.github.io/helm-charts

# 수집기 베포
helm upgrade --install fluent-bit fluent/fluent-bit \
  --version 0.52.0 \
  -n logging \
  -f helm-charts/logging/fluentbit/values.yaml 
  -f helm-charts/logging/values-dev.yaml


 ```