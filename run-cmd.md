# EKS Kubernetes 배포 명령어 실행 순서

## 전제 조건
- EKS 클러스터가 생성되어 있고 `kubectl`이 연결됨
- AWS ALB Controller가 설치되어 있음 (Ingress 사용을 위해)
- 모든 YAML 리소스는 `dev-aiagent` 네임스페이스 기준

---
## 0. 인프라 확인

```bash
# 현재 클러스터확인
kubectl config current-context
# 클러스터에 접속할수있도록 로컬 큐브컨피그에 등록
aws eks update-kubeconfig --region <리전> --name <클러스터 이름>
# 클러스터 전환
kubectl config use-context <context-name>
# pcv 확인
kubectl get pvc -A
# StorageClass 확인  
kubectl get storageclass
```

---

## 1. 인프라 설정

```bash
kubectl apply -f infra/namespace.yaml
kubectl apply -f infra/storageclass-gp3.yaml
```

## 1-1. 인프라 설정 확인

```bash
kubectl get namespace dev-aiagent
kubectl get storageclass
```

---

## 2. Redis 배포

```bash
kubectl apply -f redis/redis-pvc.yaml  
kubectl apply -f redis/redis-deployment.yaml
kubectl apply -f redis/redis-service.yaml
```

---

## 2-1. Redis 배포 확인

```bash
kubectl get pvc -n dev-aiagent  # Bound 상태확인
kubectl get pods -n dev-aiagent -l app=redis
kubectl get svc redis-service -n dev-aiagent
```

---

## 3. 설정 리소스 배포 (ConfigMap, Secret)

```bash
kubectl apply -f aiagent/aiagent-configmap.yaml
kubectl apply -f aiagent-system/aiagent-system-configmap.yaml
kubectl apply -f aiagent-api/aiagent-api-configmap.yaml
# kubectl apply -f aiagent-api/aiagent-api-secret.yaml  # 필요시 주석 해제

```

## 설정 확인
```bash
kubectl get configmap -n dev-aiagent
```
---


## 4. 애플리케이션 배포 (Deployment & Service)

```bash
kubectl apply -f aiagent/aiagent-deployment.yaml
kubectl apply -f aiagent/aiagent-service.yaml

kubectl apply -f aiagent-system/aiagent-system-deployment.yaml
kubectl apply -f aiagent-system/aiagent-system-service.yaml

kubectl apply -f aiagent-api/aiagent-api-deployment.yaml
kubectl apply -f aiagent-api/aiagent-api-service.yaml
```



## 5. Ingress 설정


```bash
kubectl apply -f infra/ingress.yaml
```

## 5-1 Ingress 베포확인
```bash
kubectl get ingress -n dev-aiagent 
kubectl describe ingress aiagent-ingress -n dev-aiagent
```


## 6. 상태 확인

```bash

kubectl get all -n dev-aiagent

kubectl get pods -n dev-aiagent
kubectl get pods -n dev-aiagent -w

kubectl get svc -n dev-aiagent

kubectl get ingress -n dev-aiagent

kubectl get deployments -n dev-aiagent

kubectl describe ingress aiagent-ingress -n dev-aiagent
```

---

## 7. 로그 확인 (문제 발생 시)

```bash

# 디테일검색
kubectl describe pod {podName} -n dev-aiagent

# 특정 Pod 로그
kubectl logs -f <pod-name> -n dev-aiagent

# Deployment별 로그
kubectl logs -f deployment/aiagent -n dev-aiagent
kubectl logs -f deployment/aiagent-system -n dev-aiagent
kubectl logs -f deployment/aiagent-api -n dev-aiagent
kubectl logs -f deployment/redis -n dev-aiagent

# 편리한 테일 10개만 최근
kubectl logs redis-74c86dc74d-pnlsg -n dev-aiagent --tail=10

#문제해결시 디플로이 파일미변경시
kubectl rollout restart deployment/{metaName} -n dev-aiagent 

```

---

## 8. 리소스 정리 (테스트 클러스터에서)

```bash
kubectl delete namespace dev-aiagent
kubectl delete storageclass gp2
```

---

## ⚠️ 운영 주의사항

1. ConfigMap에 포함된 민감 정보는 향후 Secret 리소스로 전환 필요
2. 이미지 태그가 고정되어 있음 → 최신 이미지 사용 여부 확인  
   - aiagent: 0.1.0
   - aiagent-system: 0.0.3  
   - aiagent-api: 0.1.9
3. Ingress 도메인 및 인증서 설정은 배포 전에 사전 검토 필수
4. 각 리소스에는 `metadata.namespace: dev-aiagent`가 명시되어 있어야 함



