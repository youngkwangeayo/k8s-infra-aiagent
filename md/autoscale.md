# 쿠버네티스 오토스케일링 동작 흐름

## 1️⃣ HPA 스케일 아웃 트리거
- **주체**: HPA 컨트롤러 (`kube-controller-manager` 내부, 컨트롤 플레인)
- **행동**:
  1. `metrics-server`에서 CPU/메모리 사용률 조회
  2. 목표치 초과 시 **Deployment의 Scale 서브리소스** 수정 (`.spec.replicas` 값 증가)
  3. 변경 내용은 API 서버를 거쳐 etcd에 저장

---

## 2️⃣ Deployment → ReplicaSet → Pod 생성
- **주체**: Deployment 컨트롤러 (컨트롤 플레인)
- **행동**:
  1. replicas 값 증가 확인
  2. 해당 Deployment의 **ReplicaSet**에서 **새 Pod 객체 생성**
  3. Pod는 아직 `spec.nodeName`이 비어 있는 상태로 API 서버에 `Pending` 상태로 등록

---

## 3️⃣ 스케줄러 배치
- **주체**: kube-scheduler (컨트롤 플레인)
- **행동**:
  1. `Pending` 상태의 Pod 감지
  2. 노드 후보 필터링 (Ready 상태, 리소스 여유, taint/toleration, affinity 등)
  3. 점수 계산 후 **최적 노드 선택** (기본은 분산, 라운드 로빈처럼 보일 수 있음)
  4. Pod의 `spec.nodeName`에 배정된 노드 이름 기록

---

## 4️⃣ 노드 자원 부족 시
- **조건**: 모든 노드가 자원 부족으로 스케줄 불가
- **결과**: Scheduler가 여전히 `Pending` 상태 유지 → API 서버에 반영

---

## 5️⃣ 노드 증설
- **주체**: Cluster Autoscaler(CA) 또는 Karpenter (컨트롤 플레인 외부에서 동작, 클라우드 API 호출)
- **행동**:
  1. `Pending` Pod가 일정 시간 이상 존재하는지 감시
  2. 요구 리소스에 맞는 새 노드 생성 (AWS EC2, GCP VM 등)
  3. 새 노드가 클러스터에 Join & Ready 상태로 등록

---

## 6️⃣ 새 노드에 배치
- **주체**: kube-scheduler
- **행동**:
  1. 새 노드 Ready 이벤트 감지
  2. `Pending` Pod를 새 노드에 바인딩
  3. 해당 노드의 kubelet이 컨테이너 생성 & 실행
  4. Pod 상태가 `Running`으로 전환

---

## 한 줄 요약 흐름
[HPA 컨트롤러] → Deployment replicas 증가
→ [Deployment 컨트롤러] → Pod 생성(Pending)
→ [스케줄러] → 노드 배치 or Pending 유지
→ [CA/Karpenter] → 노드 증설
→ [스케줄러] → 새 노드 배치 → Pod Running



######=========######=========######=========######=========######=========

# EKS 자동 복구 + Pod 재배치 흐름 (기존 노드에 여유 리소스가 있는 경우)

## 1️⃣ 기존 노드 비정상 감지
- **주체**: EKS Auto Healing (Managed Node Group + ASG)
- **행동**:
  - 헬스체크로 비정상 상태 감지
  - Auto Scaling Group(ASG)이 해당 노드를 종료(Terminate)
  - 동일 스펙의 새 노드 생성 절차 시작

---

## 2️⃣ Pod 재배치
- **주체**: Kubernetes Controller Manager + Scheduler
- **행동**:
  1. 비정상 노드의 Pod가 Evict됨
  2. Deployment/ReplicaSet이 새 Pod 생성
  3. 스케줄러가 다른 정상 노드의 리소스 여유 여부 확인
  4. **여유가 있다면 즉시 바인딩** → 해당 노드 kubelet이 컨테이너 실행
  5. Pod 상태가 `Running`으로 전환

    단 여유도느가 없으면 Pending 상태로 전환
---

## 3️⃣ 새 노드 생성
- **주체**: Auto Scaling Group
- **행동**:
  - 원래 계획대로 새 EC2 노드 생성 및 EKS 클러스터에 Join
  - 모든 Pod가 이미 정상 노드에서 실행 중이라면, 새 노드는 한동안 빈 상태일 수 있음
  - Cluster Autoscaler가 활성화된 경우, 일정 시간 후 스케일 인(노드 축소) 가능

    새로운 노드가 실행되면 Pending상태의 pod을 스케줄러가 새로운노드에 러닝시키고 바인드시킴
---

## 핵심 포인트
- 쿠버네티스는 **최대한 빠르게 기존 정상 노드에 Pod를 재배치**하려고 함
- 새 노드가 Ready 되기 전이라도, **자원만 충분하다면 Pending 상태 없이 바로 실행**
- Auto Healing은 "노드 수를 원래 목표치로 복원"하는 역할로, Pod 재배치와는 **독립적으로 진행**


######=========######=========######=========######=========######=========

# 쿠버네티스 - Pod 문제 vs 컨테이너 문제

## 1️⃣ Pod 자체에 문제가 있을 때
> 예: 스케줄 불가, 노드 네트워크 문제, 노드 다운 등

### 동작 흐름
1. **감지**
   - **kube-scheduler**: 스케줄링 불가 시 `Pending` 상태 유지 (`Unschedulable` 이벤트 기록)
   - **kube-controller-manager**: 노드 `NotReady` → 일정 시간 후 Pod `Evicted` 처리
2. **대응**
   - **Deployment/ReplicaSet**이 원하는 replicas 수를 유지하기 위해 다른 노드에 새 Pod 생성
   - 새 Pod → 스케줄러 배치 → kubelet 실행
3. **결과**
   - 문제가 있는 Pod는 삭제, 정상 노드에서 동일 사양의 새 Pod 실행

---

## 2️⃣ Pod 안의 컨테이너에 문제가 있을 때
> 예: 애플리케이션 프로세스 종료, CrashLoopBackOff, Liveness/Readiness probe 실패

### 동작 흐름
1. **감지**
   - **kubelet**이 컨테이너 상태를 주기적으로 체크 (Docker/Containerd 런타임 기반)
   - 설정된 **Liveness probe / Readiness probe**로 상태 확인
2. **대응**
   - **Liveness probe 실패** → kubelet이 컨테이너 **재시작**
   - **CrashLoopBackOff** → 재시작 시도, 재시작 간격 지수 증가(backoff)
   - **Readiness probe 실패** → 컨테이너는 실행 중이지만 Service Endpoints에서 제외
3. **결과**
   - 재시작 후 정상 복구 시 서비스 복귀
   - 계속 실패 시 Pod는 `CrashLoopBackOff` 상태 → 운영자가 원인 분석 필요

---

## 3️⃣ 차이 정리

| 구분 | 원인 | 감지 주체 | 대응 방식 | 결과 |
|------|------|----------|----------|------|
| **Pod 자체 문제** | 스케줄 불가, 노드 장애 | Scheduler / Controller Manager | 새 Pod 생성 & 재배치 | 새 Pod가 정상 노드에서 실행 |
| **컨테이너 문제** | 애플리케이션 장애, 프로세스 다운, Probe 실패 | kubelet | 컨테이너 재시작, Endpoints 제외 | 재시작 후 복귀 or CrashLoopBackOff |

---

## 💡 포인트
- **Pod 자체 문제** → 보통 **새 Pod 생성**이 해결책 (Deployment/ReplicaSet이 수행)
- **컨테이너 문제** → 보통 **재시작**이 해결책 (kubelet이 수행)
- Probe 설정이 정확해야 장애를 신속하게 감지 가능
- Persistent Volume 사용 시 컨테이너 재시작에도 데이터 유지 가능하지만, 새 Pod 생성 시에는 볼륨 재마운트 필요


######=========######=========######=========######=========######=========
# 쿠버네티스 노드 스케일 인(축소) 동작 흐름

## 1️⃣ 전제 조건
- **Cluster Autoscaler(CA)** 또는 **Karpenter** 설치 및 활성화
- 노드 그룹(ASG) 또는 프로비저너 정책에서 **스케일 인 허용**이 설정되어 있어야 함

---

## 2️⃣ 부하 감소 → Pod 축소
1. HPA(혹은 수동 스케일)로 **Pod replicas 수가 감소**
2. 일부 노드가 거의 빈 상태(Idling)로 변함  
   → 이 노드 위에 있는 Pod가 적거나 없음

---

## 3️⃣ 축소 후보 노드 선정
- **CA/Karpenter**가 주기적으로 모든 노드 상태 점검
- 노드에 **중요한 Pod(다른 노드로 못 옮기는 Pod)** 가 없고:
  - Local PV(로컬 스토리지 볼륨) 없음
  - Node Affinity 등으로 고정되지 않음
  - PDB(PodDisruptionBudget) 위반 안 함
- 해당 노드는 **스케일 인 후보**로 선택됨

---

## 4️⃣ Pod 드레이닝(퇴거)
- 축소 후보 노드의 **모든 Pod를 다른 노드로 이동**  
  (Deployment/ReplicaSet이 기존 replicas 수를 유지)
- `kubectl drain <node>`와 동일한 동작을 자동 수행

---

## 5️⃣ 노드 삭제
- **Cluster Autoscaler**: ASG에 인스턴스 수 감소 명령
- **Karpenter**: 클라우드 API로 인스턴스 종료
- 노드가 클러스터에서 제거됨

---

## 📌 흐름 요약