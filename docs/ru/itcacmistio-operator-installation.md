# Как установить оператор itcacmistio в Kubernetes

Здесь представлены инструкции по установке и настройке оператора `itcacmistio` для интеграции с сервисной сетью **Istio** в кластере **Kubernetes**.

Подробные сведения о работе с операторами, Kubernetes, Istio и Helm см. в [справочных материалах](#справочные-материалы).

## 1. Общая информация об операторе Kubernetes

### 1.1. Принцип работы

В этой статье мы рассматриваем установку оператора Kubernetes для использования сервисной сети Istio.

Мы установим оператор `itcacmistio`, который будет интегрирован с Istio, заменит стандартную цитадель Istio и возьмёт на себя выпуск и ротацию сертификатов вместо стандартной цитадели.

!!! question "Что такое оператор в Kubernetes"

    Когда требуется не только запускать приложение в кластере, но и осуществлять автоматизированное управление его жизненным циклом (сложные процедуры инициализации, обновления, резервное копирование и восстановление, изменение схемы базы данных, масштабирование), используются операторы Kubernetes.

    Оператор в Kubernetes — это приложение, автоматизирующее управление ПО и его жизненным циклом. Оператор автоматически реагирует на изменения в состоянии кластера, отслеживая состояние сервисов подобно живому администратору.

    См. _«[Operator в Kubernetes что это и зачем нужен](https://purpleschool.ru/knowledge-base/article/kubernetes-operator/)»_.

!!! question "Что такое Istio"

    Istio — это сервисная сеть (service mesh), представляющая собой инфраструктурный слой, который прозрачно накладывается на распределённые приложения и обеспечивает безопасное взаимодействие сервисов (mTLS), управление трафиком, балансировку нагрузки и наблюдаемость без изменений кода.

    См. _«[Istio: Обзор продукта](https://istio.io/latest/docs/overview/what-is-istio/)»_.

### 1.2. Установка оператора

#### Предварительные условия

Перед началом установки убедитесь, что выполнены следующие условия:

- развёрнут кластер Kubernetes версии 1.19+;
- у вас имеется административный доступ;
- установлена утилита `kubectl`;
- установлено ПО Helm версии 3.x;
- развёрнута сеть Istio;
- имеется доступ к реестру контейнеров с образом оператора;
- имеется чарт `itcacmistio` для Helm;
- имеется файл корневого сертификата (`Root_CA.pem`).

#### Порядок установки

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
    helm upgrade -f ./chart/cr.yandex.yaml \
      --install acmistio \
      --namespace itcacm-citadel-system \
      --set acm.caroot="$(cat ~/Root_CA.pem)" \
      --set cluster.name=cwi-prod-1 \
      --set cluster.enviroment=PROD \
      --set image.appVersion=2023.2.1-dev \
      --set acm.configServers="{https://p0esau-ap2301wn.domain.ru/api/acmcd,https://p0esau-ap2302lk.domain.ru/api/acmcd}"
    ```

    !!! question "Синтаксис команды"
    
        - `helm upgrade` — обновить релиз Helm;
        - `-f ./chart/cr.yandex.yaml` — путь к чарту Helm с параметрами установки `itcacmistio`;
        - `--install acmistio` — установить релиз, если он отсутствует, и присвоить ему имя `acmistio`;
        - `--namespace itcacm-citadel-system` — выполнить обновление в пространстве имён `itcacm-citadel-system`;
        - `--set acm.caroot` — содержимое корневого сертификата (в примере используется вложенная команда `bash` для чтения файла сертификата `$(cat ~/Root_CA.pem)`, также можно использовать встроенный параметр Helm для чтения файла `--set-file acm.caroot=~/Root_CA.pem`);
        - `--set cluster.name` — имя кластера, в котором будет работать оператор (`cwi-prod-1`);
        - `--set cluster.enviroment` — окружение оператора (`DEV`|`TEST`|`PROD`);
        - `--set image.appVersion` — версия образа оператора и тег Docker (по умолчанию `2023.2.1-dev`).
        - `--set acm.configServers` — список серверов-поставщиков конфигураций;

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

    # Проверка журналов оператора
    # Получить label можно с помощью команды:
    # kubectl get pods -n itcacm-citadel-system --show-labels
    kubectl logs -n itcacm-citadel-system -l app=acmistio
    ```

    Ожидаемый результат:
    
    - Все поды оператора в `itcacm-citadel-system` должны иметь статус `Running`.
    - Секрет `istiod-tls` должен существовать.
    - Журналы не должны содержать ошибок.

## 2. Решение типовых проблем

Если после установки оператора по приведённым выше инструкциям возникли проблемы, воспользуйтесь следующими рекомендациями.

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
# <REVISION> требуемая версия из истории
# Предпросмотр отката без изменений:
# helm rollback acmistio <REVISION> -n itcacm-citadel-system --dry-run
helm rollback acmistio <REVISION> -n itcacm-citadel-system
```

### Как проверить журналы при ошибках

При возникновении проблем выполните следующие команды:

```bash
# Журналы оператора
kubectl logs -n itcacm-citadel-system deployment/acmistio-operator

# События в пространстве имён
kubectl get events -n itcacm-citadel-system --sort-by='.lastTimestamp'

# Статус релиза Helm
helm status acmistio -n itcacm-citadel-system
```

### Как обновить сертификаты

Для обновления корневого сертификата выполните команду:

```bash
helm upgrade acmistio ./chart \
  --namespace itcacm-citadel-system \
  --set-file acm.caroot=~/Root_CA.pem \
  --reuse-values
```

## Справочные материалы

Чтобы подробнее изучить работу операторов в Kubernetes, ознакомьтесь со следующими материалами.

- [Kubernetes: оператор — что это и зачем нужен](https://purpleschool.ru/knowledge-base/article/kubernetes-operator/)
- [Kubernetes: архитектура](https://kubernetes.io/docs/concepts/architecture/)
- [Kubernetes: поды](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Kubernetes: секреты](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes: пространства имён](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Helm: использование](https://helm.sh/ru/docs/intro/using_helm/)
- [Helm: чарты](https://helm.sh/ru/docs/topics/charts/)
- [Istio: использование в Yandex Managed Service for Kubernetes](https://yandex.cloud/ru/docs/tutorials/container-infrastructure/istio)
- [Istio: обзор продукта](https://istio.io/latest/docs/overview/what-is-istio/)
- [Istio: подмена встроенного CA (plugin CA cert)](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/)
- [Istio: концепции безопасности](https://istio.io/latest/docs/concepts/security/)
