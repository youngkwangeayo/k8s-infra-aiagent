# 쿠버네티스 YAML 적용 시 내부 동작 과정

## 1. 전체 흐름 개요 (`kubectl apply` → 실행)
1. **kubectl → API 서버**
   - `kubectl`이 kubeconfig의 정보(클러스터 엔드포인트, TLS 인증서, 토큰 등)를 사용해 **kube-apiserver**로 HTTPS 요청 전송
   - 인증(Authentication) → 권한 확인(RBAC Authorization) → 어드미션(Admission) 순서로 요청 검증
   - 유효하면 **etcd**에 리소스 사양 저장

2. **컨트롤 플레인 컨트롤러 & 스케줄러 동작**
   - `kube-controller-manager`가 리소스 상태를 감시하며 **원하는 상태(Desired State)** 로 맞추기 위해 오브젝트 생성/수정
   - `kube-scheduler`가 **스케줄링 안 된 Pod**를 찾아 적절한 노드에 배정 (`nodeName` 지정)

3. **워커 노드 실행**
   - 해당 노드의 `kubelet`이 apiserver를 watch → 자신이 맡은 Pod 감지
   - 컨테이너 런타임(containerd 등)이 이미지 풀 → 컨테이너 실행
   - CNI 플러그인으로 Pod IP 설정
   - PVC 필요 시 CSI 드라이버로 PV 생성/마운트

4. **트래픽 라우팅**
   - `kube-proxy`가 Service 규칙(iptables/ipvs) 설정 → Service로 유입된 요청을 Pod로 전달
   - Ingress Controller(ALB/Nginx 등)가 외부 트래픽을 Service로 라우팅

---

## 2. 리소스별 상세 동작

### Deployment (컨테이너)
- etcd에 저장 → ReplicaSet 생성 → 지정된 수만큼 Pod 생성
- 스케줄러가 노드 배정 → kubelet이 컨테이너 실행
- 롤링 업데이트/롤백 지원

### ConfigMap
- etcd에 저장 → Pod가 env/볼륨으로 참조
- 파일 마운트 시에는 실시간 반영 가능, env는 재시작 필요

### Service
- etcd에 저장 → EndpointSlice 업데이트
- kube-proxy가 규칙 생성 → L4 로드밸런싱 수행

### Ingress
- etcd에 저장 → Ingress Controller가 감지
- 클라우드 LB(ALB 등) 또는 Nginx 라우팅 규칙 생성
- 외부 트래픽 → LB → Service → Pod

### PVC (PersistentVolumeClaim)
- etcd에 저장 → PV 존재 시 바인딩
- PV 없고 StorageClass 지정 시 **동적 프로비저닝**
- PV 생성 후 PVC와 바인딩, Pod에 마운트

### StorageClass
- PVC 생성 시 참조
- CSI 프로비저너가 정의된 파라미터로 볼륨 생성

---

## 3. Helm으로 ALB Controller 설치 시 동작
1. **helm install**
   - Helm 클라이언트가 차트 렌더링 → YAML 생성 → apiserver에 제출
2. **리소스 생성**
   - Deployment, ServiceAccount(IRSA), CRD, Webhook 등 생성
3. **ALB 프로비저닝**
   - Ingress/Service 감시 → AWS API 호출로 ALB, 리스너, 타겟그룹 생성
   - 도메인 → ALB → Target Group → NodePort/Pod

---

## 4. 마스터 → 노드 → Pod 빌드 순서 요약
1. `kubectl apply` → apiserver에 요청, etcd 저장
2. Controller가 리소스 생성, Scheduler가 Pod → 노드 매칭
3. kubelet이 이미지 풀 → 컨테이너 실행, 볼륨 마운트
4. kube-proxy가 서비스 라우팅 규칙 설정
5. Ingress Controller가 외부 LB 설정

---

