# AWS Load Balancer Controller 설치로 인한 변경사항

## 개요
AWS Load Balancer Controller v2.13.4 설치 시 AWS 계정과 Kubernetes 클러스터에 추가되는 리소스들과 예상되는 사이드 이펙트를 정리합니다.

## 1. IAM 관련 변경사항

### 1.1 OIDC Identity Provider 생성
**생성된 리소스:**
```
arn:aws:iam::365485194891:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/5462186C22D3E040F8F7644A59F243C2
```

**사이드 이펙트:**
- ✅ **긍정적:** EKS 서비스 계정이 AWS IAM 역할을 사용할 수 있게 됨
- ⚠️ **주의사항:** 동일한 EKS 클러스터의 다른 서비스 계정들도 이 OIDC Provider를 활용 가능
- 💰 **비용:** 무료 (OIDC Provider 자체는 비용 없음)

### 1.2 IAM Policy 생성
**생성된 정책:**
```
Policy Name: AWSLoadBalancerControllerIAMPolicy
ARN: arn:aws:iam::365485194891:policy/AWSLoadBalancerControllerIAMPolicy
```

**권한 내용:**
- EC2 (VPC, Subnet, SecurityGroup 조회/수정)
- ELBv2 (ALB/NLB 생성/수정/삭제)
- ACM (인증서 조회)
- WAF (웹 방화벽 연결)
- Shield (DDoS 보호)
- Route53 (DNS 레코드 수정)

**사이드 이펙트:**
- ✅ **긍정적:** ALB Controller가 필요한 AWS 리소스들을 자동 관리
- ⚠️ **보안 위험:** 과도한 권한 부여 (EC2, ELB 전체 제어 권한)
- 🔒 **권장사항:** 정기적인 권한 검토 필요

### 1.3 IAM Role 생성
**생성된 역할:**
```
Role Name: AmazonEKSLoadBalancerControllerRole
ARN: arn:aws:iam::365485194891:role/AmazonEKSLoadBalancerControllerRole
```

**Trust Policy:** 
- EKS OIDC Provider를 통해 `kube-system:aws-load-balancer-controller` ServiceAccount만 assume 가능

**사이드 이펙트:**
- ✅ **보안 강화:** 특정 ServiceAccount만 역할 사용 가능
- ⚠️ **의존성:** EKS 클러스터 삭제 시 수동으로 정리 필요

## 2. Kubernetes 리소스 변경사항

### 2.1 ServiceAccount 생성
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::365485194891:role/AmazonEKSLoadBalancerControllerRole
```

**사이드 이펙트:**
- ✅ **긍정적:** Pod가 AWS 서비스에 안전하게 접근
- ⚠️ **주의사항:** `kube-system` 네임스페이스에 추가됨

### 2.2 Deployment 생성
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
spec:
  replicas: 2  # 고가용성을 위한 2개 Pod
```

**사이드 이펙트:**
- 📊 **리소스 사용량:** CPU/Memory 사용 (모니터링 필요)
- 💰 **비용:** EKS 노드 리소스 사용으로 인한 간접 비용
- 🔄 **고가용성:** 2개 Pod로 단일 장애점 제거

### 2.3 IngressClass 생성
```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
spec:
  controller: ingress.k8s.aws/alb
```

**사이드 이펙트:**
- ✅ **긍정적:** `ingressClassName: alb` 사용 가능
- ⚠️ **기존 Ingress 영향:** 기존 Ingress 리소스가 자동으로 ALB 생성 시작

## 3. AWS 리소스 자동 생성 (Ingress 기반)

### 3.1 Application Load Balancer
**생성된 ALB:**
```
Name: k8s-devaiage-aiagenti-cba010751b
DNS: k8s-devaiage-aiagenti-cba010751b-981415296.ap-northeast-2.elb.amazonaws.com
Scheme: internet-facing
```

**사이드 이펙트:**
- 💰 **비용:** ALB 시간당 요금 + LCU 요금 발생
- 🌐 **네트워크:** 인터넷에서 접근 가능한 엔드포인트 생성
- 🔒 **보안:** SSL/TLS 터미네이션

### 3.2 Target Groups (3개)
```
1. k8s-devaiage-aiagenta-05d999e623 (aiagent-api-service)
2. k8s-devaiage-aiagents-43f0798491 (aiagent-service) 
3. k8s-devaiage-aiagents-f9271b46c7 (aiagent-system-service)
```

**사이드 이펙트:**
- 💰 **비용:** Target Group 자체는 무료, 하지만 health check 트래픽 발생
- 📊 **모니터링:** Health check 로그 및 메트릭 생성
- 🔄 **자동 복구:** Unhealthy target 자동 제외

### 3.3 Security Group 규칙 자동 추가
**추가된 규칙:**
- ALB Security Group → Pod Security Group (포트 80)
- Pod 간 통신을 위한 규칙

**사이드 이펙트:**
- 🔒 **보안 변경:** 네트워크 접근 규칙 자동 수정
- ⚠️ **의존성:** Security Group 수동 수정 시 충돌 가능성

## 4. 예상 비용

### 4.1 AWS 비용
```
ALB (Application Load Balancer)
- 시간당 요금: ~$0.0225/시간 (약 $16.20/월)
- LCU 요금: 사용량에 따라 추가

Target Group
- 무료 (Health check 트래픽은 미미)

기타
- CloudWatch 로그/메트릭: 사용량에 따라
```

### 4.2 EKS 리소스 사용량
```
Controller Pod 리소스:
- CPU: ~100m per pod (총 200m)
- Memory: ~200Mi per pod (총 400Mi)
```

## 5. 모니터링 포인트

### 5.1 필수 모니터링
- **ALB Health:** Target 상태, 응답 시간
- **Controller Logs:** 에러 및 warning 메시지
- **Cost:** ALB 및 LCU 사용량
- **Security:** IAM 역할 사용 패턴

### 5.2 권장 알람
```bash
# ALB Target 상태 모니터링
aws cloudwatch put-metric-alarm --alarm-name "ALB-UnhealthyTargets" \
  --alarm-description "ALB has unhealthy targets" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold

# Controller Pod 상태 확인
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## 6. 롤백 방법

### 6.1 완전 제거 시
```bash
# 1. Helm 제거
helm uninstall aws-load-balancer-controller -n kube-system

# 2. ServiceAccount 제거  
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system

# 3. IAM 리소스 제거
aws iam detach-role-policy --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::365485194891:policy/AWSLoadBalancerControllerIAMPolicy
aws iam delete-role --role-name AmazonEKSLoadBalancerControllerRole
aws iam delete-policy --policy-arn arn:aws:iam::365485194891:policy/AWSLoadBalancerControllerIAMPolicy
```

### 6.2 주의사항
- ⚠️ **ALB 제거:** Ingress 삭제 후 Controller 제거해야 ALB 자동 정리
- ⚠️ **DNS 영향:** Route53 레코드가 존재하면 503 에러 발생
- ⚠️ **트래픽 중단:** 롤백 중 서비스 중단 발생

## 7. 보안 권장사항

### 7.1 IAM 정책 최소화
- 현재 정책이 과도한 권한을 가지고 있음
- 실제 사용하는 권한만 허용하도록 custom policy 생성 권장

### 7.2 네트워크 보안
- ALB Security Group 규칙 정기 검토
- WAF 적용 고려
- VPC 내부 통신만 허용하는 internal ALB 고려

### 7.3 모니터링 강화
- CloudTrail을 통한 API 호출 모니터링
- GuardDuty를 통한 이상 행위 탐지