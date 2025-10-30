# Как установить оператор itcacmistio в Kubernetes

Здесь представлены инструкции по установке и настройке оператора `itcacmistio` для интеграции с **Istio service mesh** в кластере **Kubernetes**.

**Результат**: установлен оператор `itcacmistio`, который интегрирован с **Istio**, заменяет стандартную **Istio Citadel** и берёт на себя выпуск и ротацию сертификатов вместо стандартной Citadel.

Подробные сведения о работе с операторами, Kubernetes и Istio см. в [справочных материалах](#справочные-материалы).

!!! question "Что такое оператор в Kubernetes"

    Когда требуется не только запускать приложение в кластере, но и осуществлять автоматизированное управление его жизненным циклом (сложные процедуры инициализации, обновления, резервное копирование и восстановление, изменение схемы базы данных, масштабирование), используются операторы Kubernetes.

    Оператор в Kubernetes — это приложение, автоматизирующее управление ПО и его жизненным циклом. Оператор автоматически реагирует на изменения в состоянии кластера, отслеживая состояние сервисов подобно живому администратору.

    См. также статью _«[Operator в Kubernetes что это и зачем нужен](https://purpleschool.ru/knowledge-base/article/kubernetes-operator/)»_.

## Предварительные условия

Перед началом установки убедитесь, что выполнены следующие условия:

- развёрнут кластер Kubernetes версии 1.19+;
- у вас имеется административный доступ;
- установлена утилита `kubectl`;
- установлено ПО Helm версии 3.x;
- развёрнута сеть Istio;
- имеется доступ к реестру контейнеров с образом оператора;
- имеется файл корневого сертификата (`Root_CA.pem`).

## Пошаговая установка

1. Создайте пространство имён для оператора:

    ```bash
    kubectl create namespace itcacm-citadel-system
    ```

2: Создайте секрет для доступа к реестру контейнеров:

    ```bash
    kubectl create secret docker-registry registry-secret \
    --namespace itcacm-citadel-system \
    --docker-server=<REGISTRY_URL> \
    --docker-username=<USERNAME> \
    --docker-password=<PASSWORD>
    ```

    Вместо `<REGISTRY_URL>`, `<USERNAME>`, `<PASSWORD>` укажите фактические данные для доступа к Docker.

3. Установите оператор с необходимыми параметрами посредством Helm

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

    **Параметры команды:**
    
    - `acm.caroot` - содержимое корневого сертификата;
    - `cluster.name` - имя вашего кластера;
    - `cluster.enviroment` - окружение (`DEV`|`TEST`|`PROD`);
    - `acm.configServers` - список серверов конфигурации;
    - `image.appVersion` - версия образа оператора.

4. С помощью YAML-файла конфигурации автоматически выпустите сертификат в `istiod-tls`:

    ```bash
    kubectl apply -f ./config/samples/istiod-autocert.yaml -n istio-system
    ```

5. Замените стандартную Istio Citadel. Для этого отключите встроенную Citadel и активируйте собственную на основе YAML-файла конфигурации:

    ```bash
    kubectl apply -f ./config/samples/istio-config-1.12.2.yaml
    ```

6. Проверьте статус оператора:

    ```bash
    # Проверка подов оператора
    kubectl get pods -n itcacm-citadel-system

    # Проверка наличия секрета istiod-tls
    kubectl get secret istiod-tls -n istio-system

    # Проверка логов оператора
    kubectl logs -n itcacm-citadel-system -l app=acmistio
    ```

    - Все поды должны быть иметь статус `Running`.
    - Секрет `istiod-tls` должен быть создан.

## Решение типовых проблем

### Как обновить оператор до новой версии

Выполните команду установки с новыми параметрами:

```bash
helm upgrade acmistio ./chart \
  --namespace itcacm-citadel-system \
  --set image.appVersion=<NEW_VERSION> \
  --reuse-values
```

### Как откатить неудачное обновление

Для отката к предыдущей версии выполните команду:

```bash
# Посмотреть историю релизов
helm history acmistio -n itcacm-citadel-system

# Откатиться к предыдущей версии
helm rollback acmistio -n itcacm-citadel-system
```

### Как проверить журналы при ошибках

При возникновении проблем выполните следующие команды:

```bash
# Логи оператора
kubectl logs -n itcacm-citadel-system deployment/acmistio-operator

# События в namespace
kubectl get events -n itcacm-citadel-system --sort-by='.lastTimestamp'

# Статус Helm релиза
helm status acmistio -n itcacm-citadel-system
```

### Как обновить сертификаты

Для обновления корневого сертификата выполните команду:

```bash
helm upgrade acmistio ./chart \
  --namespace itcacm-citadel-system \
  --set acm.caroot="$(cat ~/new_Root_CA.pem)" \
  --reuse-values
```

## Справочные материалы

Чтобы подробнее изучить работу операторов в Kubernetes, ознакомьтесь со следующими материалами.

- [Operator в Kubernetes что это и зачем нужен](https://purpleschool.ru/knowledge-base/article/kubernetes-operator/)
- [Архитектура Kubernetes](https://kubernetes.io/docs/concepts/architecture/)
- [Pods в Kubernetes](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Секреты в Kubernetes](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Пространства имён в Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Helm Charts](https://helm.sh/docs/topics/charts/)
- [Istio: Подмена встроенного CA (plugin CA cert)](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/)
- [Istio: Концепции безопасности](https://istio.io/latest/docs/concepts/security/)
