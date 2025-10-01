# GitHub Actions 백엔드 CI/CD 파이프라인 구성 가이드

## 📋 실행정보 요약

**데옵스**: 제공된 실행정보를 기반으로 GitHub Actions CI/CD 파이프라인을 구성했습니다.

### 환경 설정
- **ACR_NAME**: acrdigitalgarage03
- **RESOURCE_GROUP**: rg-digitalgarage-03
- **AKS_CLUSTER**: aks-digitalgarage-03
- **SYSTEM_NAME**: phonebill
- **MANIFEST_REPO_URL**: https://github.com/Minseo-Jo/phonebill.git

### 백엔드 서비스 목록
- api-gateway
- user-service
- bill-service
- product-service
- kos-mock

## 🚀 구성된 CI/CD 파이프라인

### 1. 워크플로우 파일 생성
생성된 파일: `.github/workflows/backend-cicd_ArgoCD.yaml`

### 2. 주요 특징
- **변경 감지**: 서비스별 파일 변경 감지로 필요한 서비스만 빌드
- **환경별 배포**: 브랜치별 환경 자동 설정
  - `main` → prod
  - `develop` → staging
  - 기타 → dev
- **병렬 빌드**: 변경된 서비스들 동시 빌드
- **ArgoCD 연동**: 매니페스트 레포지토리 업데이트로 GitOps 구현

### 3. 파이프라인 단계
1. **detect-changes**: 변경된 서비스 감지 및 환경 설정
2. **build**: 변경된 서비스 빌드 및 테스트 (병렬)
3. **release**: Docker 이미지 빌드 및 푸시 (병렬)
4. **update-manifest**: 매니페스트 레포지토리 업데이트

## 🔐 필수 GitHub Secrets 설정

### 실행정보 기반 설정값

**데옵스**: 다음 GitHub Secrets을 설정해야 합니다:

#### Azure Container Registry 접근
```
ACR_USERNAME: <ACR 사용자명>
ACR_PASSWORD: <ACR 패스워드>
```

#### Git 매니페스트 레포지토리 접근
```
GIT_USERNAME: <GitHub 사용자명>
GIT_PASSWORD: <GitHub Personal Access Token>
```

### Secrets 설정 방법

1. **GitHub 레포지토리 설정 접근**
   - GitHub 레포지토리 페이지로 이동
   - Settings > Secrets and variables > Actions 메뉴 선택

2. **New repository secret 클릭하여 추가**
   - Name: `ACR_USERNAME`, Value: ACR 사용자명
   - Name: `ACR_PASSWORD`, Value: ACR 패스워드
   - Name: `GIT_USERNAME`, Value: GitHub 사용자명
   - Name: `GIT_PASSWORD`, Value: GitHub PAT

3. **GitHub Personal Access Token 생성**
   - GitHub Settings > Developer settings > Personal access tokens
   - Generate new token (classic) 선택
   - 권한: `repo` (전체), `write:packages` 선택
   - 생성된 토큰을 `GIT_PASSWORD`로 사용

## 📦 ACR 연결 정보 확인

**데옵스**: ACR 접근 정보를 확인하는 방법입니다:

### Azure CLI로 ACR 정보 확인
```bash
# ACR 로그인 정보 확인
az acr credential show --name acrdigitalgarage03 --resource-group rg-digitalgarage-03

# 출력 예시:
# {
#   "passwords": [
#     {
#       "name": "password",
#       "value": "xxxxxxxxxxxxx"
#     }
#   ],
#   "username": "acrdigitalgarage03"
# }
```

### 환경변수 설정 (참고)
```bash
export ACR_USERNAME="acrdigitalgarage03"
export ACR_PASSWORD="<password value>"
```

## 🏗️ 매니페스트 레포지토리 구조

**데옵스**: ArgoCD 연동을 위한 매니페스트 구조는 다음과 같아야 합니다:

```
phonebill/
├── kustomize/
│   ├── base/
│   │   ├── api-gateway/
│   │   ├── user-service/
│   │   ├── bill-service/
│   │   ├── product-service/
│   │   ├── kos-mock/
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── prod/
```

## ⚡ 파이프라인 실행 조건

### 트리거 조건
- **Push**: `main`, `develop` 브랜치에 푸시
- **Pull Request**: `main` 브랜치로의 PR
- **경로 필터**: 서비스 디렉토리 또는 `common` 모듈 변경 시

### 빌드 최적화
- 변경된 서비스만 빌드하여 실행 시간 단축
- `common` 모듈 변경 시 모든 서비스 빌드
- 캐시를 통한 Gradle 의존성 최적화

## 🎯 ArgoCD 연동 특징

**데옵스**: 기존 직접 배포 방식에서 GitOps 방식으로 변경했습니다:

### 변경 사항
- ❌ `kubectl apply` 직접 배포 제거
- ✅ 매니페스트 레포지토리 업데이트로 대체
- ✅ ArgoCD가 자동으로 변경사항 감지 및 배포
- ✅ Git 기반 배포 이력 관리

### 장점
- 배포 이력의 Git 기반 추적
- 롤백의 용이성 (Git revert)
- 환경별 매니페스트 관리 일원화
- 배포 승인 프로세스 적용 가능

## 🔧 트러블슈팅

### 일반적인 문제들

1. **ACR 접근 오류**
   - GitHub Secrets의 ACR 자격증명 확인
   - ACR 활성화 상태 확인

2. **매니페스트 업데이트 실패**
   - GitHub Secrets의 Git 자격증명 확인
   - Personal Access Token 권한 확인

3. **Kustomize 디렉토리 없음**
   - 매니페스트 레포지토리 구조 확인
   - 환경별 overlay 디렉토리 존재 확인

4. **이미지 푸시 실패**
   - ACR 용량 및 권한 확인
   - 네트워크 연결 상태 확인

## ✅ 검증 방법

### 파이프라인 동작 확인
1. 서비스 코드 수정 후 커밋/푸시
2. GitHub Actions 탭에서 워크플로우 실행 확인
3. 각 Job별 로그 확인
4. ACR에서 이미지 푸시 확인
5. 매니페스트 레포지토리에서 이미지 태그 업데이트 확인

**데옵스**: GitHub Actions를 통한 백엔드 CI/CD 파이프라인 구성이 완료되었습니다. 제공된 실행정보를 기반으로 최적화된 워크플로우를 생성했습니다.