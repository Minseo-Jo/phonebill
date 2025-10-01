#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

# 환경별 이미지 태그 업데이트
cd deployment/cicd/kustomize/overlays/${ENVIRONMENT}

# 서비스 목록 (공백으로 구분, 실제 서비스명으로 교체)
services="api-gateway user-service bill-service product-service kos-mock"

# 각 서비스 이미지 태그 업데이트
for service in $services; do
    kustomize edit set image acrdigitalgarage03.azurecr.io/phonebill/$service:${ENVIRONMENT}-${IMAGE_TAG}
done

# 배포 실행
kubectl apply -k .

# 배포 상태 확인
for service in $services; do
    kubectl rollout status deployment/$service -n phonebill-dg0515
done

echo "✅ Deployment completed successfully!"