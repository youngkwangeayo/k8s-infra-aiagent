
## 기본명령어

```bash
kubectl delete namespace dev-aiagent
kubectl delete storageclass gp2


# 클러스터에 접속할수있도록 로컬 큐브컨피그에 등록
aws eks update-kubeconfig --region <리전> --name <클러스터 이름>


# 접속된 클러스터확인
kubectl config current-context 

# 사용 가능한 클러스터 목록(컨텍스트 목록) 보기
kubectl config get-contexts

# 클러스터 전환
kubectl config use-context <context-name>



# 노드관련
kubectl get nodes



## 팟관련 ##
# 전체보기
kubectl get pods -A

# 네임스페이스검색
kubectl get pods -n <네임스페이스이름>


# 상세조회
kubectl describe pvc redis-pvc -n dev-aiagent


# 팟 로그 진행 <팟네임> <네임스페이스:옵션> <테일10개 최근것만>
kubectl logs redis-74c86dc74d-pnlsg -n dev-aiagent --tail=10


kubectl top node


#컨테이너 진입
kubectl exec -it aiagent-646c9c6f8d-4955g -n dev-aiagent -- /bin/bash
```

