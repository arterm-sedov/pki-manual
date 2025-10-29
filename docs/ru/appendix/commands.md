# Справочник команд для установки оператора itcacmistio

Данный документ содержит все команды, используемые при установке и настройке оператора itcacmistio. Команды готовы для копирования и выполнения.

## Установка

### Создание namespace

```bash
kubectl create namespace itcacm-citadel-system
```

### Создание секрета для доступа к registry

```bash
kubectl create secret docker-registry registry-secret \
  --namespace itcacm-citadel-system \
  --docker-server=<REGISTRY_URL> \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD>
```

### Установка оператора

Полная команда установки:

```bash
helm upgrade --install acmistio ./chart \
  --namespace itcacm-citadel-system \
  --set acm.caroot="$(cat ~/Root_CA.pem)" \
  --set cluster.name=cwi-prod-1 \
  --set cluster.enviroment=PROD \
  --set image.appVersion=2023.2.1-dev \
  --set acm.configServers="{https://p0esau-ap2301wn.domain.ru/api/acmcd,https://p0esau-ap2302lk.domain.ru/api/acmcd}" \
  -f ./chart/cr.yandex.yaml
```

Команда с минимальными параметрами:

```bash
helm install acmistio ./chart \
  --namespace itcacm-citadel-system \
  --set acm.caroot="$(cat ~/Root_CA.pem)" \
  --set cluster.name=<CLUSTER_NAME> \
  --set acm.configServers="{<CONFIG_SERVER_URL>}"
```

### Настройка Istio интеграции

Создание сертификата:

```bash
kubectl apply -f ./config/samples/istiod-autocert.yaml -n istio-system
```

Замена Citadel:

```bash
kubectl apply -f ./config/samples/istio-config-1.12.2.yaml
```

## Проверка установки

### Статус компонентов

```bash
# Проверка подов оператора
kubectl get pods -n itcacm-citadel-system

# Детальная информация о подах
kubectl describe pods -n itcacm-citadel-system

# Проверка deployment
kubectl get deployment -n itcacm-citadel-system
```

### Проверка секретов

```bash
# Проверка секрета для registry
kubectl get secret registry-secret -n itcacm-citadel-system

# Проверка сертификата istiod
kubectl get secret istiod-tls -n istio-system

# Детали сертификата
kubectl describe secret istiod-tls -n istio-system
```

### Просмотр логов

```bash
# Логи всех подов оператора
kubectl logs -n itcacm-citadel-system -l app=acmistio

# Логи с отслеживанием в реальном времени
kubectl logs -f -n itcacm-citadel-system -l app=acmistio

# Логи конкретного пода
kubectl logs -n itcacm-citadel-system <POD_NAME>

# Предыдущие логи (если под перезапускался)
kubectl logs -n itcacm-citadel-system <POD_NAME> --previous
```

## Управление релизом

### Информация о релизе

```bash
# Статус релиза
helm status acmistio -n itcacm-citadel-system

# История релизов
helm history acmistio -n itcacm-citadel-system

# Значения текущего релиза
helm get values acmistio -n itcacm-citadel-system
```

### Обновление

```bash
# Обновление с сохранением существующих значений
helm upgrade acmistio ./chart \
  --namespace itcacm-citadel-system \
  --reuse-values \
  --set image.appVersion=<NEW_VERSION>

# Обновление с новым файлом значений
helm upgrade acmistio ./chart \
  --namespace itcacm-citadel-system \
  -f ./chart/values-prod.yaml
```

### Откат

```bash
# Откат к предыдущей версии
helm rollback acmistio -n itcacm-citadel-system

# Откат к конкретной версии
helm rollback acmistio <REVISION_NUMBER> -n itcacm-citadel-system
```

## Диагностика

### События и ошибки

```bash
# События в namespace
kubectl get events -n itcacm-citadel-system --sort-by='.lastTimestamp'

# События для конкретного объекта
kubectl get events -n itcacm-citadel-system --field-selector involvedObject.name=<POD_NAME>
```

### Ресурсы и метрики

```bash
# Потребление ресурсов подами
kubectl top pods -n itcacm-citadel-system

# Описание ресурсов
kubectl describe resourcequota -n itcacm-citadel-system
kubectl describe limitrange -n itcacm-citadel-system
```

## Удаление

### Удаление оператора

```bash
# Удаление через Helm
helm uninstall acmistio -n itcacm-citadel-system

# Удаление namespace
kubectl delete namespace itcacm-citadel-system

# Удаление CRD (если требуется)
kubectl delete crd <CRD_NAME>
```

### Очистка Istio конфигурации

```bash
# Восстановление стандартной Citadel
kubectl delete -f ./config/samples/istio-config-1.12.2.yaml

# Удаление сертификата
kubectl delete secret istiod-tls -n istio-system
```

## Полезные alias'ы

Добавьте в ваш `.bashrc` или `.zshrc`:

```bash
# Быстрый доступ к namespace оператора
alias kacm='kubectl -n itcacm-citadel-system'

# Логи оператора
alias acmlogs='kubectl logs -f -n itcacm-citadel-system -l app=acmistio'

# Статус оператора
alias acmstatus='kubectl get pods -n itcacm-citadel-system'
```
