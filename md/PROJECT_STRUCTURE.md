# AI Agent Kubernetes Project Structure

## 📁 프로젝트 개요
Kubernetes 환경에서 AI Agent 시스템을 운영하기 위한 인프라 코드 및 배포 매니페스트 집합

## 📂 디렉토리 구조

```
aiagent-k8s/
│
├── 📁 bakend-app/                     # 백엔드 API 서버
│   ├── aiagent-api-configmap.yaml        # ConfigMap  환경변수 및 설정 관리 구성 명세
│   ├── aiagent-api-deployment.yaml       # Deployment  배포 및 롤링 업데이트 명세
│   ├── aiagent-api-secret.yaml           # Secret 서버 민감정보 (DB 인증 aceess키 등) 명세
│   ├── aiagent-api-service.yaml          # Service 앱별 서비스 접근 규칙 명세 (ClusterIP)
│   └── info.txt                          # 기본적 txt 파일
│
├── 📁 ai-app/                          # ai 서버
│   └── ... 위와같음
│
├── 📁 front-app/                           # 메인 프론트엔드 앱
│   └── ... 위와같음
│
├── 📁 aws/                        # AWS 관련 설정 및 스크립트
│   └── install-alb-controller-awscli.sh # CLI 기반 ALB 컨트롤러 헬름차트로 설치(내/외부 네트워크 경로 설정)
│
├── 📁 infra/                            # 클러스터 인프라 구성
│   ├── hpa.yaml                         # HorizontalPodAutoscaler (자동 스케일링)
│   ├── info.txt                         # 인프라 정보
│   ├── ingress.yaml                     # Ingress 설정 (ALB 연동 및 외부에서 내부 들어온 전체 라우팅 규칙 명세 )
│   ├── namespace.yaml                   # NabeSpace 네임스페이스 정의 
│   └── storageclass-gp3.yaml            # StorageClass 스토리지 클래스 영구 보존 스토리지 정의
│
├── 📁 md/                               # 문서 모음
│   ├── run-cmd.md                       # 실행 명령어 가이드 
│   └── ...                              # 실행 명령어 가이드 
│
├── 📁 redis/                        # Redis 캐시 서버
│   ├── redis-deployment.yaml           # Deployment  배포 및 롤링 업데이트 명세
│   ├── redis-pvc.yaml                  # PVC 영구 볼륨 클레임 정의
│   ├── redis-service.yaml              # Service 앱별 서비스 접근 규칙 명세 (ClusterIP)
│   └── info.txt                        # Redis 정보
│
└── README.md                            # 프로젝트 기본 정보 및 구성 가이드
```

## 🏗️ 아키텍처 구성

### 서비스 계층
1. **외부 트래픽** → ALB (Application Load Balancer)
2. **Ingress** → 경로별 라우팅 (/api, /system, /)
3. **Service** → Pod 그룹으로 로드밸런싱
4. **Pod** → 실제 애플리케이션 실행

### 애플리케이션 구성요소
- **aiagent**: 메인 프론트엔드 앱 (경로: `/`)
- **aiagent-system**: 시스템 관리 UI (경로: `/system`)
- **aiagent-api**: 백엔드 API 서버 (경로: `/api`)
- **redis**: 세션/캐시 저장소



## 🔧 주요 특징

### 자동 스케일링
- **HPA**: CPU 사용률 60% 기준으로 3-10개 Pod 자동 스케일링
- **Cluster Autoscaler**: 노드 부족 시 워커 노드 자동 추가

### 로드밸런싱
- **ALB**: AWS Application Load Balancer를 통한 외부 트래픽 분산
- **Service**: 클러스터 내부 Pod 간 트래픽 분산
- **kube-proxy**: iptables/IPVS 기반 네트워크 라우팅

### 저장소
- **GP3 StorageClass**: 고성능 SSD 스토리지 클래스
- **PVC**: Redis 데이터 영구 저장
- **ConfigMap**: 애플리케이션 설정 분리

### 보안 및 모니터링
- **Secret**: 민감정보 암호화 저장
- **RBAC**: 역할 기반 접근 제어
- **Health Check**: readinessProbe/livenessProbe 설정

## 📖 참고 문서
- `md/run-cmd.md`: 실행 명령어 가이드
- `md/process흐름도.md`: Kubernetes 내부 동작 원리
- `md/autoscale.md`: 자동 스케일링 설정 가이드
- `aws/ALB-Controller-Changes.md`: ALB 컨트롤러 변경사항
