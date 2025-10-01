# 백엔드 Jenkins CI/CD 파이프라인 구축 가이드

## 📋 개요

이 문서는 phonebill 프로젝트를 위한 Jenkins + Kustomize 기반 CI/CD 파이프라인 구축 가이드입니다.

### 프로젝트 정보
- **시스템명**: phonebill
- **서비스 목록**: api-gateway, user-service, bill-service, product-service, kos-mock
- **JDK 버전**: 21
- **실행 환경**:
  - ACR명: acrdigitalgarage03
  - 리소스 그룹: rg-digitalgarage-03
  - AKS 클러스터: aks-digitalgarage-03
  - 네임스페이스: phonebill-dg0515

## 🏗️ 아키텍처 구성

### 디렉토리 구조
```
deployment/cicd/
├── kustomize/
│   ├── base/                           # 기본 매니페스트
│   │   ├── common/                     # 공통 리소스
│   │   │   ├── cm-common.yaml
│   │   │   ├── secret-common.yaml
│   │   │   ├── secret-imagepull.yaml
│   │   │   └── ingress.yaml
│   │   ├── api-gateway/                # API Gateway 리소스
│   │   ├── user-service/               # User Service 리소스
│   │   ├── bill-service/               # Bill Service 리소스
│   │   ├── product-service/            # Product Service 리소스
│   │   ├── kos-mock/                   # KOS Mock 리소스
│   │   └── kustomization.yaml          # Base Kustomization
│   └── overlays/                       # 환경별 오버레이
│       ├── dev/                        # 개발 환경
│       │   ├── kustomization.yaml
│       │   ├── cm-common-patch.yaml
│       │   ├── ingress-patch.yaml
│       │   ├── deployment-*-patch.yaml
│       │   └── secret-*-patch.yaml
│       ├── staging/                    # 스테이징 환경
│       └── prod/                       # 운영 환경
├── config/                             # 환경별 설정
│   ├── deploy_env_vars_dev
│   ├── deploy_env_vars_staging
│   └── deploy_env_vars_prod
├── scripts/                            # 유틸리티 스크립트
│   ├── deploy.sh
│   └── validate-resources.sh
└── Jenkinsfile                         # Jenkins 파이프라인
```

## 🚀 Jenkins 서버 환경 구성

### 1. 필수 플러그인 설치

Jenkins 관리 → 플러그인 관리에서 다음 플러그인들을 설치하세요:

```
- Kubernetes
- Pipeline Utility Steps
- Docker Pipeline
- GitHub
- SonarQube Scanner
- Azure Credentials
```

### 2. Jenkins Credentials 등록

Jenkins 관리 → Credentials → Add Credentials에서 다음 자격증명들을 등록하세요:

#### Azure Service Principal
```
Kind: Microsoft Azure Service Principal
ID: azure-credentials
Subscription ID: {구독ID}
Client ID: {클라이언트ID}
Client Secret: {클라이언트시크릿}
Tenant ID: {테넌트ID}
Azure Environment: Azure
```

#### ACR Credentials
```
Kind: Username with password
ID: acr-credentials
Username: acrdigitalgarage03
Password: {ACR_PASSWORD}
```

#### Docker Hub Credentials (Rate Limit 해결용)
```
Kind: Username with password
ID: dockerhub-credentials
Username: {DOCKERHUB_USERNAME}
Password: {DOCKERHUB_PASSWORD}
참고: Docker Hub 무료 계정 생성 (https://hub.docker.com)
```

#### SonarQube Token
```
Kind: Secret text
ID: sonarqube-token
Secret: {SonarQube토큰}
```

## 📋 Jenkins Pipeline Job 생성

### 1. Pipeline Job 생성
1. Jenkins 웹 UI에서 **New Item** 클릭
2. **Pipeline** 선택
3. 프로젝트명 입력 (예: phonebill-backend-cicd)

### 2. Pipeline 설정
**Pipeline 탭에서 다음 설정:**
```
Definition: Pipeline script from SCM
SCM: Git
Repository URL: {Git저장소URL}
Branch: main (또는 develop)
Script Path: deployment/cicd/Jenkinsfile
```

### 3. Pipeline Parameters 설정
**General 탭에서 "This project is parameterized" 체크 후:**

#### ENVIRONMENT (Choice Parameter)
```
Name: ENVIRONMENT
Choices:
dev
staging
prod
Default Value: dev
Description: 배포할 환경을 선택하세요
```

#### IMAGE_TAG (String Parameter)
```
Name: IMAGE_TAG
Default Value: latest
Description: 컨테이너 이미지 태그 (선택사항)
```

#### SKIP_SONARQUBE (String Parameter)
```
Name: SKIP_SONARQUBE
Default Value: true
Description: SonarQube 분석 건너뛰기 (true/false)
```

## 🔧 SonarQube 프로젝트 설정

### 각 서비스별 프로젝트 생성
SonarQube에서 다음 프로젝트들을 생성하세요:
- phonebill-api-gateway-dev
- phonebill-user-service-dev
- phonebill-bill-service-dev
- phonebill-product-service-dev
- phonebill-kos-mock-dev

### Quality Gate 설정
```
Coverage: >= 80%
Duplicated Lines: <= 3%
Maintainability Rating: <= A
Reliability Rating: <= A
Security Rating: <= A
```

## 🚀 배포 실행 방법

### 1. Jenkins 파이프라인 실행
1. Jenkins → {프로젝트명} → **Build with Parameters** 클릭
2. 파라미터 설정:
   - **ENVIRONMENT**: dev/staging/prod 선택
   - **IMAGE_TAG**: 이미지 태그 입력 (선택사항)
   - **SKIP_SONARQUBE**: SonarQube 분석 건너뛰려면 "true", 실행하려면 "false"
3. **Build** 클릭

### 2. 수동 배포 스크립트 실행
```bash
# 개발 환경에 최신 태그로 배포
./deployment/cicd/scripts/deploy.sh dev latest

# 운영 환경에 특정 태그로 배포
./deployment/cicd/scripts/deploy.sh prod 20241001120000
```

### 3. 배포 상태 확인
```bash
# Pod 상태 확인
kubectl get pods -n phonebill-dg0515

# 서비스 상태 확인
kubectl get services -n phonebill-dg0515

# Ingress 상태 확인
kubectl get ingress -n phonebill-dg0515

# 배포 롤아웃 상태 확인
kubectl rollout status deployment/user-service -n phonebill-dg0515
```

## 🔄 롤백 방법

### 1. 이전 버전으로 롤백
```bash
# 특정 버전으로 롤백
kubectl rollout undo deployment/{서비스명} -n phonebill-dg0515 --to-revision=2

# 롤백 상태 확인
kubectl rollout status deployment/{서비스명} -n phonebill-dg0515
```

### 2. 이미지 태그 기반 롤백
```bash
# 이전 안정 버전 이미지 태그로 업데이트
cd deployment/cicd/kustomize/overlays/{환경}
kustomize edit set image acrdigitalgarage03.azurecr.io/phonebill/{서비스명}:{환경}-{이전태그}
kubectl apply -k .
```

## 🔍 검증 및 모니터링

### 1. 리소스 검증 스크립트 실행
```bash
# Kustomize 리소스 누락 검증
./deployment/cicd/scripts/validate-resources.sh
```

### 2. 환경별 빌드 테스트
```bash
# 개발 환경 빌드 테스트
kubectl kustomize deployment/cicd/kustomize/overlays/dev/

# 스테이징 환경 빌드 테스트
kubectl kustomize deployment/cicd/kustomize/overlays/staging/

# 운영 환경 빌드 테스트
kubectl kustomize deployment/cicd/kustomize/overlays/prod/
```

### 3. 파이프라인 모니터링
- Jenkins 파이프라인 실행 로그 확인
- SonarQube Quality Gate 결과 확인
- Kubernetes 배포 상태 모니터링

## 🛠️ 파이프라인 단계 설명

### 1. Get Source
- Git 저장소에서 소스코드 체크아웃
- 환경별 설정 파일 읽기

### 2. Setup AKS
- Azure 서비스 주체 인증
- AKS 클러스터 연결
- Namespace 생성/확인

### 3. Build
- Gradle을 사용한 프로젝트 빌드
- 테스트 제외 빌드 (성능 최적화)

### 4. SonarQube Analysis & Quality Gate
- 각 서비스별 개별 SonarQube 분석
- 테스트 실행 및 코드 커버리지 생성
- Quality Gate 확인 및 실패 시 파이프라인 중단

### 5. Build & Push Images
- Podman을 사용한 컨테이너 이미지 빌드
- 환경별 이미지 태그 설정
- ACR에 이미지 푸시

### 6. Update Kustomize & Deploy
- Kustomize 설치 및 이미지 태그 업데이트
- Kubernetes 매니페스트 적용
- 배포 상태 확인 및 대기

## 📊 환경별 구성 차이점

| 구분 | DEV | STAGING | PROD |
|------|-----|---------|------|
| **Replicas** | 1 | 2 | 3 |
| **CPU Request** | 256m | 512m | 1024m |
| **Memory Request** | 256Mi | 512Mi | 1024Mi |
| **CPU Limit** | 1024m | 2048m | 4096m |
| **Memory Limit** | 1024Mi | 2048Mi | 4096Mi |
| **Profile** | dev | staging | prod |
| **DDL Auto** | update | validate | validate |
| **JWT Token Validity** | 5시간 | 5시간 | 1시간 |
| **SSL Redirect** | false | true | true |
| **HTTPS** | 미사용 | 사용 | 사용 |

## ⚠️ 주의사항

### 1. 파드 자동 정리
- 파이프라인 완료 시 에이전트 파드 자동 삭제
- `podRetention: never()` 설정으로 리소스 절약

### 2. 변수 참조 문법
- Jenkins Groovy에서 `${variable}` 사용
- `\${variable}` 사용 시 문법 오류 발생

### 3. SonarQube 선택적 실행
- `SKIP_SONARQUBE=true` 파라미터로 건너뛰기 가능
- 개발 단계에서 빠른 배포를 위해 활용

### 4. 보안 고려사항
- Secrets는 stringData 형식 사용
- 운영 환경에서는 JWT 토큰 유효시간 단축
- HTTPS 강제 적용 (staging/prod)

## 🚨 문제 해결

### 1. 파이프라인 실패 시
```bash
# Jenkins 로그 확인
# SonarQube Quality Gate 결과 확인
# Kubernetes 이벤트 확인
kubectl get events -n phonebill-dg0515 --sort-by=.metadata.creationTimestamp
```

### 2. Kustomize 빌드 실패 시
```bash
# 리소스 검증 스크립트 실행
./deployment/cicd/scripts/validate-resources.sh

# 수동 빌드 테스트
kubectl kustomize deployment/cicd/kustomize/overlays/dev/
```

### 3. 이미지 빌드/푸시 실패 시
- ACR 인증 정보 확인
- Docker Hub 로그인 상태 확인
- 네트워크 연결 상태 확인

## ✅ 체크리스트

### 파이프라인 구축 완료 체크
- [ ] Jenkins 플러그인 설치 완료
- [ ] Credentials 등록 완료
- [ ] SonarQube 프로젝트 생성 완료
- [ ] Pipeline Job 생성 및 설정 완료
- [ ] 리소스 검증 스크립트 실행 성공
- [ ] 개발 환경 배포 테스트 성공
- [ ] 롤백 절차 테스트 완료

### 운영 준비 체크
- [ ] 스테이징 환경 배포 테스트 성공
- [ ] 운영 환경 도메인 및 SSL 인증서 설정
- [ ] 모니터링 및 알람 설정
- [ ] 백업 및 복구 절차 수립

---

**최종 업데이트**: 2024-10-01
**문서 버전**: 1.0
**작성자**: 데옵스팀