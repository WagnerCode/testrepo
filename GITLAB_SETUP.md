# Настройка GitLab CI/CD для деплоя Corax на ALT Linux (Shell Runner)

Данный документ описывает настройку GitLab CI/CD переменных и подготовку окружения для автоматизированного развертывания кластера Corax на ALT Linux 10.2 с использованием GitLab Runner в режиме **shell executor**.

## Оглавление

- [Предварительные требования](#предварительные-требования)
- [Настройка GitLab Runner](#настройка-gitlab-runner)
- [Подготовка дистрибутивов на Runner](#подготовка-дистрибутивов-на-runner)
- [Настройка GitLab CI/CD переменных](#настройка-gitlab-cicd-переменных)
- [Подготовка SSH ключей](#подготовка-ssh-ключей)
- [Структура Pipeline](#структура-pipeline)
- [Примеры конфигурации](#примеры-конфигурации)
- [Запуск Pipeline](#запуск-pipeline)
- [Troubleshooting](#troubleshooting)

---

## Предварительные требования

### Инфраструктура

1. **GitLab Runner (shell executor)**
   - Установлен GitLab Runner в режиме shell
   - Доступ к интернету (опционально, для обновлений)
   - Установлены необходимые утилиты: `python3`, `jq`, `ssh`, `scp`
   - Директория `/test-distribs` для размещения дистрибутивов Corax

2. **Деплой нода** - сервер с ALT Linux 10.2, с которого будет производиться развертывание
   - Минимум 2 CPU, 4GB RAM, 20GB диск
   - Установлена ОС ALT Linux 10.2
   - Открыт SSH доступ (порт 22)

3. **Рабочие ноды кластера** - серверы для установки компонентов Corax
   - Рекомендуется минимум 3 ноды для отказоустойчивого кластера
   - Каждая нода: минимум 4 CPU, 8GB RAM, 100GB диск
   - Установлена ОС ALT Linux 10.2
   - Открыт SSH доступ (порт 22)

---

# Для ALT Linux через apt-get
sudo apt-get update
sudo apt-get install -y python3 python3-module-pip jq openssh-clients rsync unzip tree
```

## Подготовка архива Corax на Runner

### Создание директории для архива

На машине с GitLab Runner создайте директорию для хранения архива Corax:

```bash
sudo mkdir -p /test-distribs
sudo chown gitlab-runner:gitlab-runner /test-distribs
sudo chmod 755 /test-distribs
```

**Примечание:** Если пользователь, от имени которого запускается runner, отличается от `gitlab-runner`, замените его на актуальное имя.

### Подготовка архива corax_prepare.zip

Архив `corax_prepare.zip` должен содержать полную структуру проекта Corax со всеми необходимыми файлами и дистрибутивами.

**Структура архива:**

```
corax_prepare/
├── ansible.cfg
├── files/
│   ├── KFK-11.340.0-16-distrib.zip         # Дистрибутив Kafka/Corax
│   ├── ansible_corax_json_exporter.zip      # JSON exporter
│   ├── corax-scriptMerger-2.0.0.zip        # Script merger
│   ├── group_vars_all.j2                    # Шаблон group_vars (не используется в CI)
│   ├── inventory.j2                         # Шаблон inventory (не используется в CI)
│   ├── post_install_corax.yaml              # Пост-установочный playbook
│   ├── prepare.sh                           # Скрипт подготовки дистрибутивов
│   └── prepare_corax.yaml                   # Playbook подготовки Corax
├── group_vars/
│   └── all.yaml                             # Будет заменен CI/CD
├── inventory.ini                            # Будет заменен CI/CD
├── playbook.yaml                            # Основной playbook
├── lvm.yaml                                 # LVM playbook (опционально)
└── tmp/                                     # Временные файлы (опционально)
```

**Важные замечания:**
- Дистрибутивы (KFK-*.zip, corax-*.zip, ansible_*.zip) должны находиться в директории `files/`
- Файлы `inventory.ini` и `group_vars/all.yaml` будут автоматически сгенерированы и заменены pipeline
- Архив должен распаковываться с созданием директории `corax_prepare/` (не в корень)

### Создание архива

Создайте архив из структуры проекта:

```bash
# Перейдите в родительскую директорию проекта
cd /path/to/parent

# Создайте архив
zip -r corax_prepare.zip corax_prepare/

# Или, если вы уже в директории проекта:
cd /path/to/corax_prepare
cd ..
zip -r corax_prepare.zip corax_prepare/
```

### Размещение архива на Runner

Скопируйте архив `corax_prepare.zip` в директорию `/test-distribs` на runner:

```bash
# Копирование с локальной машины
scp corax_prepare.zip gitlab-runner@runner-host:/test-distribs/

# Или через wget, если архив доступен по URL
ssh gitlab-runner@runner-host
cd /test-distribs
wget https://example.com/path/to/corax_prepare.zip
```

### Проверка архива на Runner

```bash
ssh gitlab-runner@runner-host
ls -lh /test-distribs/
```

Ожидаемый вывод:

```
total 500M
-rw-r--r-- 1 gitlab-runner gitlab-runner 500M Jan 12 10:00 corax_prepare.zip
```

Проверьте целостность архива:

```bash
unzip -t /test-distribs/corax_prepare.zip
```

Просмотрите содержимое архива:

```bash
unzip -l /test-distribs/corax_prepare.zip | head -30
```

**Важно:**
- Если используется другая версия KFK, обновите переменную `KFK_VERSION` в GitLab CI/CD или в файле `ci/variables.yml`
- Убедитесь, что имя архива `corax_prepare.zip` совпадает с переменной `CORAX_ARCHIVE` в `ci/variables.yml`

---

## Настройка GitLab CI/CD переменных

Перейдите в GitLab: **Settings → CI/CD → Variables → Expand**

### Обязательные переменные

#### 1. `DEPLOY_NODE_HOST`
- **Тип:** Variable
- **Значение:** IP адрес деплой ноды
- **Пример:** `10.10.11.41`
- **Protected:** ✓ (рекомендуется)
- **Masked:** ✓ (рекомендуется)

#### 2. `SSH_PRIVATE_KEY`
- **Тип:** File
- **Значение:** Приватный SSH ключ для доступа к нодам
- **Protected:** ✓ (обязательно)
- **Masked:** - (не применимо для File)
- **Описание:** Приватный ключ в формате PEM. См. раздел [Подготовка SSH ключей](#подготовка-ssh-ключей)

#### 3. `CORAX_NODES`
- **Тип:** Variable
- **Значение:** JSON массив с описанием нод кластера
- **Protected:** ✓ (рекомендуется)
- **Masked:** - (содержит структурированные данные)
- **Пример:**
```json
[
  {
    "name": "corax-node1",
    "host": "10.10.11.42",
    "user": "root",
    "roles": ["kafka", "zookeeper"]
  },
  {
    "name": "corax-node2",
    "host": "10.10.11.43",
    "user": "root",
    "roles": ["kafka", "zookeeper"]
  },
  {
    "name": "corax-node3",
    "host": "10.10.11.44",
    "user": "root",
    "roles": ["kafka", "zookeeper", "crxsr", "crxui"]
  }
]
```

**Описание полей:**
- `name` - имя хоста (используется в inventory)
- `host` - IP адрес ноды
- `user` - пользователь для SSH подключения (обычно `root`)
- `roles` - массив ролей для ноды:
  - `kafka` - брокер Kafka
  - `zookeeper` - сервер Zookeeper
  - `crxsr` - Corax Schema Registry
  - `crxui` - Corax UI

---

### Опциональные переменные

Эти переменные имеют значения по умолчанию (см. `ci/variables.yml`) и могут быть переопределены при необходимости.

#### Пользователи

- `DEPLOY_NODE_USER` - по умолчанию: `root`
- `ANSIBLE_USER` - по умолчанию: `user1`

#### Пути на целевых нодах

- `KAFKA_INSTALL_DIR` - по умолчанию: `/pub/opt/Apache/kafka`
- `KAFKA_DATA_DIR` - по умолчанию: `/pub/KAFKADATA`
- `ZOOKEEPER_DATA_DIR` - по умолчанию: `/pub/zookeeper`
- `CORAX_DIR` - по умолчанию: `/pub/corax`

#### Порты сервисов

- `CRXUI_PORT` - по умолчанию: `9090`
- `CRXSR_PORT` - по умолчанию: `8081`

#### Версия дистрибутива

- `KFK_VERSION` - по умолчанию: `11.340.0-16`

#### Путь к дистрибутивам на Runner

- `DISTRIBS_DIR` - по умолчанию: `/test-distribs`

Если дистрибутивы размещены в другой директории на runner, укажите её в этой переменной.

---

## Подготовка SSH ключей

### 1. Генерация SSH ключа

Если у вас еще нет SSH ключа для деплоя:

```bash
# Генерация нового RSA ключа
ssh-keygen -t rsa -b 4096 -C "gitlab-ci-corax" -f ~/.ssh/corax_deploy_key -N ""

# Результат:
# ~/.ssh/corax_deploy_key       - приватный ключ (для GitLab Variable)
# ~/.ssh/corax_deploy_key.pub   - публичный ключ (для authorized_keys на нодах)
```

### 2. Добавление публичного ключа на все ноды

Публичный ключ необходимо добавить в `~/.ssh/authorized_keys` на:
- Деплой ноде
- Всех рабочих нодах кластера

**Вариант 1: Использование ssh-copy-id**

```bash
# Копирование на деплой ноду
ssh-copy-id -i ~/.ssh/corax_deploy_key.pub root@10.10.11.41

# Копирование на рабочие ноды
ssh-copy-id -i ~/.ssh/corax_deploy_key.pub root@10.10.11.42
ssh-copy-id -i ~/.ssh/corax_deploy_key.pub root@10.10.11.43
ssh-copy-id -i ~/.ssh/corax_deploy_key.pub root@10.10.11.44
```

**Вариант 2: Ручное добавление**

На каждой ноде выполните:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Добавьте публичный ключ в authorized_keys
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... gitlab-ci-corax
EOF

chmod 600 ~/.ssh/authorized_keys
```

### 3. Добавление приватного ключа в GitLab

Скопируйте приватный ключ:

```bash
cat ~/.ssh/corax_deploy_key
```

Затем в GitLab:
1. Перейдите в **Settings → CI/CD → Variables → Add Variable**
2. **Key:** `SSH_PRIVATE_KEY`
3. **Type:** File
4. **Value:** Вставьте содержимое приватного ключа
5. **Flags:**
   - ✓ Protect variable
   - ✓ Expand variable reference
6. **Add variable**

---

## Структура Pipeline

Pipeline разбит на модули для удобства модификации:

```
.gitlab-ci.yml                      # Главный файл (включает модули)
├── ci/
│   ├── stages.yml                  # Определение stages
│   ├── variables.yml               # Глобальные переменные
│   ├── templates.yml               # Переиспользуемые шаблоны
│   └── jobs/
│       ├── config_generation.yml   # Job генерации конфигов
│       └── node_preparation.yml    # Job подготовки деплой ноды
```

### Stage 1: config_generation

**Автоматический запуск**

- Проверяет наличие архива `corax_prepare.zip` в `/test-distribs` на runner
- Распаковывает архив во временную рабочую директорию
- Генерирует `inventory.ini` из переменной `CORAX_NODES`
- Генерирует `group_vars/all.yaml` с параметрами компонентов из GitLab CI/CD переменных
- Заменяет сгенерированные файлы в распакованной структуре
- Обновляет `ansible.cfg` с правильными настройками
- Добавляет SSH ключ в структуру
- Создает манифест конфигурации
- Сохраняет всю подготовленную структуру как артефакт

**Длительность:** ~1-2 минуты

**Примечание:** Этот stage НЕ требует копирования отдельных дистрибутивов - они уже находятся в архиве `corax_prepare.zip` в директории `files/`.

### Stage 2: node_preparation

**Ручной запуск (requires manual approval)**

- Проверяет SSH доступ к деплой ноде
- Устанавливает необходимые пакеты на деплой ноде (ansible, unzip, java-17, jq, rsync, и т.д.)
- Создает директорию `${CORAX_DIR}` на деплой ноде (с backup старой версии если существует)
- **Копирует всю подготовленную структуру из артефактов на деплой ноду через rsync**
- Настраивает SSH ключи для доступа к рабочим нодам
- Проверяет доступность рабочих нод из inventory
- Выполняет тестовый Ansible ping

**Длительность:** ~3-7 минут

**Примечание:** Вся структура Corax (включая дистрибутивы в `files/`) копируется одной операцией rsync, что значительно упрощает процесс.

---

## Примеры конфигурации

### Минимальная конфигурация (single-node)

Для тестового окружения с одной нодой:

```json
[
  {
    "name": "corax-all-in-one",
    "host": "10.10.11.50",
    "user": "root",
    "roles": ["kafka", "zookeeper", "crxsr", "crxui"]
  }
]
```

### Продуктивная конфигурация (3-node кластер)

Рекомендуемая конфигурация для продуктивного окружения:

```json
[
  {
    "name": "corax-kafka1",
    "host": "10.10.11.42",
    "user": "root",
    "roles": ["kafka", "zookeeper"]
  },
  {
    "name": "corax-kafka2",
    "host": "10.10.11.43",
    "user": "root",
    "roles": ["kafka", "zookeeper"]
  },
  {
    "name": "corax-kafka3",
    "host": "10.10.11.44",
    "user": "root",
    "roles": ["kafka", "zookeeper", "crxsr", "crxui"]
  }
]
```


---

## Запуск Pipeline

### 1. Проверка готовности

Убедитесь, что:
- ✓ GitLab Runner работает в режиме shell
- ✓ Архив `corax_prepare.zip` размещен в `/test-distribs` на runner
- ✓ Архив содержит все необходимые файлы и дистрибутивы в структуре `corax_prepare/`
- ✓ Необходимые утилиты установлены на runner (python3, jq, ssh, scp, rsync, unzip)
- ✓ Все GitLab CI/CD переменные настроены
- ✓ Публичный SSH ключ добавлен на деплой ноду и все рабочие ноды
- ✓ Все ноды доступны по SSH

### 2. Запуск Pipeline

1. Перейдите в **CI/CD → Pipelines**
2. Нажмите **Run Pipeline**
3. Выберите ветку (например, `main`)
4. Нажмите **Run Pipeline**

### 3. Мониторинг выполнения

#### Stage 1: config_generation (автоматический)

Pipeline автоматически выполнит stage генерации конфигурации:
- Проверит наличие обязательных переменных
- Сгенерирует конфигурационные файлы
- Создаст артефакты

Просмотрите лог выполнения job `generate_configs`.

#### Stage 2: node_preparation (manual)

После успешного завершения первого stage:
1. Нажмите кнопку **Play** (▶) на job `prepare_deploy_node`
2. Pipeline выполнит подготовку деплой ноды
3. Дистрибутивы будут автоматически скопированы с runner на деплой ноду

### 4. Просмотр артефактов

Для просмотра сгенерированных конфигов:
1. Откройте job `generate_configs`
2. В правой части нажмите **Browse** или **Download**
3. Просмотрите содержимое директории `generated_configs/`



### Модификация Pipeline

Для изменения логики pipeline отредактируйте соответствующие файлы:

- **Добавить/изменить stage:** `ci/stages.yml`
- **Изменить переменные:** `ci/variables.yml`
- **Изменить логику генерации конфигов:** `ci/jobs/config_generation.yml`
- **Изменить логику подготовки ноды:** `ci/jobs/node_preparation.yml`
- **Добавить переиспользуемые шаблоны:** `ci/templates.yml`
