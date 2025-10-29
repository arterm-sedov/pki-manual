#!/bin/bash
# Примеры создания секрета для доступа к container registry

echo "=== Создание секрета для Docker Hub ==="
kubectl create secret docker-registry registry-secret \
  --namespace itcacm-citadel-system \
  --docker-server=docker.io \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email@example.com

echo -e "\n=== Создание секрета для private registry ==="
kubectl create secret docker-registry registry-secret \
  --namespace itcacm-citadel-system \
  --docker-server=registry.example.com:5000 \
  --docker-username=robot-account \
  --docker-password='your-token-here' \
  --docker-email=ops@example.com

echo -e "\n=== Создание секрета из файла .dockerconfigjson ==="
# Если у вас уже есть файл ~/.docker/config.json
kubectl create secret generic registry-secret \
  --namespace itcacm-citadel-system \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson

echo -e "\n=== Создание секрета для GitLab Registry ==="
kubectl create secret docker-registry registry-secret \
  --namespace itcacm-citadel-system \
  --docker-server=registry.gitlab.com \
  --docker-username=gitlab-deploy-token \
  --docker-password='gldt-xxxxxxxxxxxx' \
  --docker-email=noreply@gitlab.com

echo -e "\n=== Создание секрета для Harbor ==="
kubectl create secret docker-registry registry-secret \
  --namespace itcacm-citadel-system \
  --docker-server=harbor.example.com \
  --docker-username='robot$project+name' \
  --docker-password='your-robot-token'

echo -e "\n=== Проверка созданного секрета ==="
kubectl get secret registry-secret -n itcacm-citadel-system -o yaml

echo -e "\n=== Привязка секрета к ServiceAccount (если требуется) ==="
kubectl patch serviceaccount default \
  -n itcacm-citadel-system \
  -p '{"imagePullSecrets": [{"name": "registry-secret"}]}'

echo -e "\n=== Альтернатива: создание секрета через YAML ==="
cat <<EOF > registry-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  namespace: itcacm-citadel-system
type: kubernetes.io/dockerconfigjson
data:
  # Значение .dockerconfigjson должно быть base64-encoded
  # Используйте: cat ~/.docker/config.json | base64 -w 0
  .dockerconfigjson: <BASE64_ENCODED_DOCKER_CONFIG>
EOF

echo "Применить YAML файл: kubectl apply -f registry-secret.yaml"
