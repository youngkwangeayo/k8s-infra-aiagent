시나리오별 오토스케일링 동작 정리
시나리오 1) 노드 1대가 비정상 종료(유실/NotReady)될 때
전제: Deployment/ReplicaSet으로 운영, Service로 트래픽 분배, HPA 활성화, (선택) CA/Karpenter 동작

노드 장애 감지

노드 상태가 Ready → NotReady.

서비스 Endpoints에서 해당 노드의 Pod가 자동 제외(트래픽 차단).

Pod 퇴거(Eviction) 판단

몇십 초~수 분 내 컨트롤 플레인이 그 노드의 Pod를 삭제 대상으로 간주.

ReplicaSet/Deployment가 원하는 replicas 수를 맞추기 위해 다른 노드에 대체 Pod 생성.

스케줄링

스케줄러가 남은 노드들 중 리소스/어피니티 제약을 만족하는 노드에 새 Pod를 배치.

남은 노드 리소스가 부족하면 Pod는 Pending으로 대기.

노드 증설(있다면)

Cluster Autoscaler/Karpenter가 Pending 파드를 감지해 새 노드 생성 → Ready가 되면 스케줄러가 즉시 바인딩.

장애 노드가 복구될 때

예전 Pod가 “그대로” 살아나지는 않음(이미 다른 곳에 대체 Pod가 떴다면 기존 Pod는 정리).

필요 시 이후 배치에서 그 노드에도 새 Pod가 올 수 있음.

✅ 체크포인트

podAntiAffinity/topologySpreadConstraints로 분산 배치 강제.

**PDB(PodDisruptionBudget)**가 너무 빡세면 재스케줄 지연.

StatefulSet+EBS는 볼륨 어태치/디태치 제약으로 복구 속도에 영향.

시나리오 2) 트래픽 급증(부하 ↑) → HPA 스케일 아웃
전제: HPA(minReplicas, maxReplicas, 목표 CPU/메모리 또는 외부 지표), metrics-server/adapter 설치

메트릭 수집 & 평가(폴링)

kubelet/cAdvisor → metrics-server → HPA 컨트롤러가 주기적으로 지표 조회.

Pod 단위 사용률의 평균이 목표치 초과 시 권장 replicas 계산.

replicas 조정

HPA가 대상 리소스(Deployment 등)의 Scale 서브리소스 패치 → replicas ↑.

ReplicaSet이 새 Pod 생성.

노드 배치

스케줄러가 조건 충족 노드에 새 Pod를 배치.

여유가 없으면 Pending → CA/Karpenter 증설 → 새 노드 준비 후 배치.

✅ 팁

짧은 스파이크에는 HPA scaleUp 정책(예: stepwise, stabilizationWindow)을 조정.

외부 큐 길이 등 커스텀/외부 메트릭을 쓰면 더 정교한 스케일 가능.

시나리오 3) 스케줄 불가(Pending) → 노드 증설
전제: Cluster Autoscaler(Managed Node Group) 또는 Karpenter 사용

Pending 발생

새 Pod에 필요한 CPU/메모리/어피니티/스토리지 조건 충족 노드 없음.

증설 판단

CA/Karpenter가 Pending 사유를 분석 → 적합한 인스턴스 타입/노드 그룹 산정.

노드 생성(수 분 소요 가능).

스케줄링 완료

노드 Ready → 스케줄러가 Pending 파드를 새 노드에 바인딩 → 트래픽 흡수.

✅ 차이

Cluster Autoscaler: 노드 그룹 단위 증감, 기존 풀에 맞춰 확장.

Karpenter: Pod 요구에 맞춘 온디맨드 프로비저닝(인스턴스 타입/스팟/가용영역을 유연하게 선택).

시나리오 4) 부하 감소(트래픽 ↓) → 스케일 인
HPA 다운스케일

평균 사용률이 목표보다 낮고 stabilizationWindow(안정화 창) 경과 → replicas ↓.

노드 축소

Pod가 줄어 노드에 유휴 리소스가 늘면

CA: “빈 노드/이동 가능한 Pod”를 파악 → 드레이닝 후 노드 삭제.

Karpenter: Consolidation로 비용 최적화(더 적은/저렴한 노드로 재배치).

✅ 주의

PDB/어피니티/로컬PV 등으로 인해 노드 축소가 막힐 수 있음.

다운스케일을 너무 공격적으로 하면 플랩핑(늘었다 줄었다) 발생 → 정책 보수적으로.

시나리오 5) 초기값 불일치: Deployment replicas: 2 vs HPA minReplicas: 4
배포 직후 2개 기동.

HPA가 최소치 4 미달을 감지 → 즉시 replicas=4로 패치.

스케줄러가 2개 추가 Pod 배치(부족하면 노드 증설).

이후는 일반적인 HPA 로직(지표 기반 상/하향).

시나리오 6) StatefulSet + 스토리지 주의
EBS: 동일 AZ 제약, 디태치/어태치 지연 → 재스케줄 느릴 수 있음.

Local PV/hostPath: 노드 종속 데이터 → 다른 노드 재기동 불가(복구 전략/레플리카 설계 필요).

“신호/흐름”을 한 줄로 요약
지표: kubelet → metrics-server/adapter → HPA 컨트롤러(폴링)

스케일 명령: HPA → 대상 리소스 Scale 패치 → ReplicaSet이 Pod 생성/삭제

배치: 스케줄러가 노드 선택(필터→스코어→바인딩)

인프라 확장: Pending 감지 시 CA/Karpenter가 노드 증설/축소

운영 시 추천 설정(핵심만)
분산 강제: podAntiAffinity, topologySpreadConstraints

HPA Behavior: stabilizationWindowSeconds, policies(percent/absolute, periodSeconds)

리소스 요청: resources.requests를 현실적으로(너무 낮게 두면 과스케줄)

PDB: 가용성 목표에 맞춰 설정(너무 빡세면 축소/이동 불가)

Karpenter/CA: 인스턴스 패밀리/가용영역/스팟 정책을 워크로드 특성에 맞춤