# 구조별 파일 나눈 기준
> 
> Service 오브젝트는 디플로이먼트로 생성된 파드들을 클러스터 내부 또는 외부로 접근할 수 있도록 연결하는
>


# 📁 필수 YAML 파일 구조 (서비스별)
>   1. 공통 인프라
>   namespace.yaml – 네임스페이스 정의 (예: aiagent 네임스페이스)
>   
>   ingress.yaml – 전체 ingress 설정 (ALB 연동 포함)
>   
>   2. aiagent-api (백엔드 앱서버)
>   aiagent-api-deployment.yaml – Deployment (레플리카 수, 이미지, 환경변수 등 포함)
>   
>   aiagent-api-service.yaml – Service (ClusterIP 또는 LoadBalancer)
>   
>   aiagent-api-configmap.yaml (선택) – 설정파일 분리 시
>   
>   aiagent-api-secret.yaml (선택) – DB 인증 정보 등
>   
>   3. aiagent-system (프론트 앱서버)
>   aiagent-system-deployment.yaml
>   
>   aiagent-system-service.yaml
>   
>   aiagent-system-ingress.yaml (URL path: /system 등으로 분기할 경우)
>   
>   4. aiagent (프론트 앱서버)
>   aiagent-deployment.yaml
>   
>   aiagent-service.yaml
>   
>   aiagent-ingress.yaml (URL path: / 등 기본 루트로 분기할 경우)
>   
>   5. redis
>   redis-deployment.yaml (또는 StatefulSet, 필요 시)
>   
>   redis-service.yaml (type: ClusterIP)
>   
>   redis-configmap.yaml (선택) – 비밀번호 및 포트 설정 등
>   
>   redis-secret.yaml (선택) – 비밀번호 분리할 경우

# ✅ 추가적으로 고려하면 좋은 파일
>   hpa.yaml – HorizontalPodAutoscaler (부하에 따라 자동 스케일링)
>   
>   pvc.yaml – PersistentVolumeClaim (Redis나 로그 저장소 필요 시)
>   
>   networkpolicy.yaml – 보안 제어 목적
>   
>   rbac.yaml – 권한 제어 필요 시
>   
>   serviceaccount.yaml – 서비스 계정 정의 (EKS IAM 연동 등)


# 👇 구성: 마스터 1대, 워커 노드 2대 (각 3~4개 Pod 가동)
>   계층	로그 위치	확인 방법
>   Pod (App)	stdout/stderr	kubectl logs
>   노드 (EC2)	/var/log/containers	Fluent Bit가 수집
>   클러스터 전체	CloudWatch (혹은 ELK, Loki)	검색, 대시보드, 알림 가능


# 오토스케일링
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60



# ready 상태 체크 트래픽주기전 레디가 되어야만 트레픽을 줌
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5

readinessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1



# 로그
앱에서 console.log(), logger.info(), System.out.println() 등으로 찍는 로그

보통 stdout, stderr로 나감 (도커 컨테이너 표준 로그)
선택지	특징	언제 사용?
stdout/stderr	Kubernetes 기본 전략, 로그 수집기 연동 쉬움	가능하면 이걸로 변경
PVC + 파일로그	기존 로그 구조 유지하면서 외부 저장	로그 구조 바꾸기 어려운 경우
hostPath + 파일로그	빠르게 로컬 테스트	노드 종속 OK일 때만


CNCF 클라우딩컴퓨팅 재단에서 Fluent Bit 로깅을 위한 소프트웨어 사용 클러스터에서 활용

Fluent Bit, Fluentd



# 로드밸런싱 내'외부 아이피
계층	              |  구성 요소	                   | 역할
외부 -> 클러스터 진입  | 	LoadBalancer or Ingress     |	클러스터에 진입시킬 트래픽의 진입점
클러스터 내부       	|  Service (type: ClusterIP)   |	 동일 라벨 파드들로 부하 분산
노드 내부       	   |  kube-proxy	                |  실제로 파드로 라우팅되는 네트워크 설정 (iptables/IPVS 기반)
파드 ->  앱         | 	파드	                       |  실제 앱이 요청 처리


# 노드 오토스케일링 구성
Cluster Autoscaler 깔아야함
Pod가 요청한 자원이 현재 노드들에서 부족한 경우


# 팁 get pods 명령시 레디와 스테이터스
STATUS != Running일 때 가능한 상태와 원인들
STATUS	주요 원인	관련 Probe
Pending	아직 스케줄링 중 (노드 부족, PVC 대기 등)	❌ readinessProbe 실행되지 않음
ContainerCreating	이미지 Pull 중, Volume attach 중 등	❌ readinessProbe 실행 전
CrashLoopBackOff	컨테이너가 계속 죽음	⛔ livenessProbe 실패 가능성 높음
Error	컨테이너 내부 오류로 종료	없음
Terminating	삭제 중	없음
Running이지만 READY는 0/1	컨테이너는 살아있지만 준비 상태 아님	✅ 이 때가 readinessProbe 실패 상태

READY: 0/1 → readinessProbe 실패 