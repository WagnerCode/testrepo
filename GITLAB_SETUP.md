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
   - Директория `/distribs` для размещения дистрибутивов Corax

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

## Настройка GitLab Runner

### Проверка GitLab Runner

Убедитесь, что GitLab Runner установлен и работает в режиме shell:

```bash
# Проверка статуса runner
sudo gitlab-runner status

# Просмотр конфигурации
sudo cat /etc/gitlab-runner/config.toml
```

В конфигурации должно быть указано `executor = "shell"`:

```toml
[[runners]]
  name = "my-shell-runner"
  url = "https://gitlab.example.com/"
  token = "..."
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
```

### Установка необходимых утилит на Runner

На машине с GitLab Runner должны быть установлены следующие утилиты:

```bash
# Для Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y python3 python3-pip jq openssh-client

# Для RHEL/CentOS/ALT Linux
sudo yum install -y python3 python3-pip jq openssh-clients

# Или для ALT Linux через apt-get
sudo apt-get update
sudo apt-get install -y python3 python3-module-pip jq openssh-clients
```

Проверка установленных утилит:

```bash
python3 --version  # Python 3.x
jq --version       # jq-1.x
ssh -V             # OpenSSH_x.x
scp -V             # OpenSSH_x.x
```

---

## Подготовка дистрибутивов на Runner

### Создание директории для дистрибутивов

На машине с GitLab Runner создайте директорию для хранения дистрибутивов Corax:

```bash
sudo mkdir -p /distribs
sudo chown gitlab-runner:gitlab-runner /distribs
sudo chmod 755 /distribs
```

**Примечание:** Если пользователь, от имени которого запускается runner, отличается от `gitlab-runner`, замените его на актуальное имя.

### Размещение дистрибутивов

Скопируйте дистрибутивы Corax в директорию `/distribs`:

```bash
# Пример копирования с локальной машины
scp KFK-11.340.0-16-distrib.zip gitlab-runner@runner-host:/distribs/
scp corax-scriptMerger-2.0.0.zip gitlab-runner@runner-host:/distribs/
scp ansible_corax_json_exporter.zip gitlab-runner@runner-host:/distribs/

# Или через wget, если файлы доступны по URL
ssh gitlab-runner@runner-host
cd /distribs
wget https://example.com/path/to/KFK-11.340.0-16-distrib.zip
wget https://example.com/path/to/corax-scriptMerger-2.0.0.zip
wget https://example.com/path/to/ansible_corax_json_exporter.zip
```

### Проверка наличия дистрибутивов

```bash
ssh gitlab-runner@runner-host
ls -lh /distribs/
```

Ожидаемый вывод:

```
total 500M
-rw-r--r-- 1 gitlab-runner gitlab-runner 450M Jan 12 10:00 KFK-11.340.0-16-distrib.zip
-rw-r--r-- 1 gitlab-runner gitlab-runner  30M Jan 12 10:01 corax-scriptMerger-2.0.0.zip
-rw-r--r-- 1 gitlab-runner gitlab-runner  20M Jan 12 10:02 ansible_corax_json_exporter.zip
```

**Важно:** Если используется другая версия KFK, обновите переменную `KFK_VERSION` в GitLab CI/CD или в файле `ci/variables.yml`.

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

- `DISTRIBS_DIR` - по умолчанию: `/distribs`

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

- Генерирует `inventory.ini` из переменной `CORAX_NODES`
- Генерирует `group_vars/all.yaml` с параметрами компонентов
- Создает `ansible.cfg` с настройками Ansible
- Сохраняет SSH ключ для последующего использования
- Создает артефакты для следующего stage

**Длительность:** ~1-2 минуты

### Stage 2: node_preparation

**Ручной запуск (requires manual approval)**

- Проверяет SSH доступ к деплой ноде
- Устанавливает необходимые пакеты на деплой ноде (ansible, unzip, java-17, jq, и т.д.)
- Создает структуру директорий для Corax
- Копирует конфигурационные файлы на деплой ноду
- **Копирует дистрибутивы с runner (/distribs) на деплой ноду**
- Настраивает SSH ключи для доступа к рабочим нодам
- Проверяет доступность рабочих нод

**Длительность:** ~5-10 минут

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

### Расширенная конфигурация (выделенные ноды для компонентов)

```json
[
  {
    "name": "zk1",
    "host": "10.10.11.51",
    "user": "root",
    "roles": ["zookeeper"]
  },
  {
    "name": "zk2",
    "host": "10.10.11.52",
    "user": "root",
    "roles": ["zookeeper"]
  },
  {
    "name": "zk3",
    "host": "10.10.11.53",
    "user": "root",
    "roles": ["zookeeper"]
  },
  {
    "name": "kafka1",
    "host": "10.10.11.61",
    "user": "root",
    "roles": ["kafka"]
  },
  {
    "name": "kafka2",
    "host": "10.10.11.62",
    "user": "root",
    "roles": ["kafka"]
  },
  {
    "name": "kafka3",
    "host": "10.10.11.63",
    "user": "root",
    "roles": ["kafka"]
  },
  {
    "name": "corax-services",
    "host": "10.10.11.70",
    "user": "root",
    "roles": ["crxsr", "crxui"]
  }
]
```

---

## Запуск Pipeline

### 1. Проверка готовности

Убедитесь, что:
- ✓ GitLab Runner работает в режиме shell
- ✓ Дистрибутивы Corax размещены в `/distribs` на runner
- ✓ Необходимые утилиты установлены на runner (python3, jq, ssh, scp)
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

### 5. После успешного выполнения Pipeline

Подключитесь к деплой ноде и запустите развертывание Corax:

```bash
# Подключение к деплой ноде
ssh root@10.10.11.41

# Переход в директорию Corax
cd /pub/corax

# Проверка структуры
ls -la

# Шаг 1: Подготовка дистрибутивов
ansible-playbook -i inventories/inventory.ini playbook.yaml

# Шаг 2: Подготовка окружения Corax
ansible-playbook -i inventories/inventory.ini prepare_corax.yaml

# Шаг 3: Развертывание Kafka и Zookeeper
ansible-playbook -i inventories/inventory.ini playbooks/kafka-zookeeper-SE.yml -t enabled_service
ansible-playbook -i inventories/inventory.ini playbooks/kafka-zookeeper-SE.yml

# Шаг 4: Развертывание Corax Schema Registry
ansible-playbook -i inventories/inventory.ini playbooks/crxsr.yml -t root,install,start

# Шаг 5: Развертывание Corax UI
ansible-playbook -i inventories/inventory.ini playbooks/crxui.yml -t root,install

# Шаг 6: Пост-установочная конфигурация
ansible-playbook -i inventories/inventory.ini post_install_corax.yaml
```

---

## Troubleshooting

### Ошибка: "python3 not found" на runner

**Проблема:** На runner не установлен Python 3.

**Решение:**
```bash
# Установка на runner
ssh gitlab-runner@runner-host
sudo apt-get install -y python3 python3-pip
```

### Ошибка: "Directory /distribs does not exist"

**Проблема:** Директория с дистрибутивами не найдена на runner.

**Решение:**
```bash
ssh gitlab-runner@runner-host
sudo mkdir -p /distribs
sudo chown gitlab-runner:gitlab-runner /distribs
# Скопируйте дистрибутивы в /distribs
```

### Ошибка: "SSH connection failed"

**Проблема:** Pipeline не может подключиться к деплой ноде.

**Решение:**
1. Проверьте корректность IP адреса в `DEPLOY_NODE_HOST`
2. Убедитесь, что публичный ключ добавлен в `~/.ssh/authorized_keys` на деплой ноде
3. Проверьте SSH сервис: `systemctl status sshd`
4. Проверьте firewall
5. Попробуйте подключиться вручную с runner:
   ```bash
   ssh gitlab-runner@runner-host
   ssh -i ~/.ssh/id_rsa root@<DEPLOY_NODE_HOST>
   ```

### Ошибка: "apt-get update failed" на деплой ноде

**Проблема:** Не удается обновить список пакетов на ALT Linux.

**Решение:**
1. Проверьте настройки репозиториев на деплой ноде
2. Убедитесь, что нода имеет доступ к интернету или внутренним репозиториям
3. Проверьте DNS
4. Попробуйте вручную: `ssh root@<DEPLOY_NODE_HOST> "apt-get update -v"`

### Ошибка: "Package not found"

**Проблема:** Не найден пакет (например, `java-17-openjdk`).

**Решение:**
1. Проверьте версию ALT Linux: `cat /etc/altlinux-release`
2. Для ALT Linux 10.2 проверьте доступные пакеты: `apt-cache search openjdk`
3. Обновите список пакетов в `ci/jobs/node_preparation.yml`, если необходимо

### Ошибка: "Ansible ping failed"

**Проблема:** Ansible не может подключиться к рабочим нодам кластера.

**Решение:**
1. Убедитесь, что публичный ключ распространен на все рабочие ноды
2. Проверьте inventory: `cat /pub/corax/inventories/inventory.ini`
3. Проверьте подключение вручную с деплой ноды:
   ```bash
   ssh root@<DEPLOY_NODE_HOST>
   ssh -i ~/.ssh/id_rsa root@<WORKER_NODE_IP>
   ```
4. Проверьте формат переменной `CORAX_NODES` - должен быть валидный JSON

### Ошибка: "Invalid JSON in CORAX_NODES"

**Проблема:** Некорректный формат переменной CORAX_NODES.

**Решение:**
1. Проверьте JSON на валидность: https://jsonlint.com/
2. Убедитесь, что все кавычки правильные (используйте `"`, не `'`)
3. Убедитесь, что нет лишних запятых
4. Пример корректного формата см. в разделе [Примеры конфигурации](#примеры-конфигурации)

### Ошибка: "Distribs not found"

**Проблема:** Дистрибутивы не найдены в `/distribs` на runner.

**Решение:**
1. Проверьте наличие файлов:
   ```bash
   ssh gitlab-runner@runner-host
   ls -lh /distribs/
   ```
2. Убедитесь, что имена файлов соответствуют ожидаемым (с учетом версии KFK)
3. Если используется другая директория, установите переменную `DISTRIBS_DIR` в GitLab

### Модификация Pipeline

Для изменения логики pipeline отредактируйте соответствующие файлы:

- **Добавить/изменить stage:** `ci/stages.yml`
- **Изменить переменные:** `ci/variables.yml`
- **Изменить логику генерации конфигов:** `ci/jobs/config_generation.yml`
- **Изменить логику подготовки ноды:** `ci/jobs/node_preparation.yml`
- **Добавить переиспользуемые шаблоны:** `ci/templates.yml`

После изменения закоммитьте и запушьте в репозиторий.

---

## Дополнительные ресурсы

- [Документация GitLab Runner](https://docs.gitlab.com/runner/)
- [Документация GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [Документация ALT Linux](https://www.altlinux.org/)
- [Документация Ansible](https://docs.ansible.com/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)

---

**Версия документа:** 2.0
**Дата обновления:** 2025-01-12
**Целевая платформа:** ALT Linux 10.2
**Версия Corax:** KFK 11.340.0-16
**Runner executor:** shell
