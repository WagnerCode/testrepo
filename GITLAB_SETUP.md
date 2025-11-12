# Настройка GitLab CI/CD для деплоя Corax на ALT Linux

Данный документ описывает настройку GitLab CI/CD переменных и подготовку окружения для автоматизированного развертывания кластера Corax на ALT Linux 10.2.

## Оглавление

- [Предварительные требования](#предварительные-требования)
- [Настройка GitLab CI/CD переменных](#настройка-gitlab-cicd-переменных)
  - [Обязательные переменные](#обязательные-переменные)
  - [Опциональные переменные](#опциональные-переменные)
- [Подготовка SSH ключей](#подготовка-ssh-ключей)
- [Примеры конфигурации](#примеры-конфигурации)
- [Запуск pipeline](#запуск-pipeline)
- [Troubleshooting](#troubleshooting)

---

## Предварительные требования

### Инфраструктура

1. **Деплой нода** - сервер с ALT Linux 10.2, с которого будет производиться развертывание
   - Минимум 2 CPU, 4GB RAM, 20GB диск
   - Установлена ОС ALT Linux 10.2
   - Открыт SSH доступ (порт 22)

2. **Рабочие ноды кластера** - серверы для установки компонентов Corax (Kafka, Zookeeper, CRXSR, CRXUI)
   - Рекомендуется минимум 3 ноды для отказоустойчивого кластера
   - Каждая нода: минимум 4 CPU, 8GB RAM, 100GB диск
   - Установлена ОС ALT Linux 10.2
   - Открыт SSH доступ (порт 22)

3. **GitLab Runner** - для выполнения CI/CD pipeline
   - Тип: Docker executor
   - Доступ к интернету для скачивания образов

### Дистрибутивы Corax

Необходимо подготовить следующие файлы дистрибутивов (размещаются в директории `files/`):

- `KFK-11.340.0-16-distrib.zip` - основной дистрибутив Kafka/Corax
- `corax-scriptMerger-2.0.0.zip` - утилиты для работы с конфигами
- `ansible_corax_json_exporter.zip` - экспортер метрик

**Важно:** После выполнения stage `node_preparation`, эти файлы нужно будет вручную загрузить на деплой ноду в директорию `/pub/corax/files/`.

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
- `name` - имя хоста (будет использовано в inventory)
- `host` - IP адрес ноды
- `user` - пользователь для SSH подключения (обычно `root`)
- `roles` - массив ролей для ноды:
  - `kafka` - брокер Kafka
  - `zookeeper` - сервер Zookeeper
  - `crxsr` - Corax Schema Registry
  - `crxui` - Corax UI

---

### Опциональные переменные

Эти переменные имеют значения по умолчанию и могут быть переопределены при необходимости.

#### `DEPLOY_NODE_USER`
- **По умолчанию:** `root`
- **Описание:** Пользователь для подключения к деплой ноде

#### `ANSIBLE_USER`
- **По умолчанию:** `user1`
- **Описание:** Пользователь Ansible для подключения к рабочим нодам

#### `KAFKA_INSTALL_DIR`
- **По умолчанию:** `/pub/opt/Apache/kafka`
- **Описание:** Директория установки Kafka и компонентов Corax

#### `KAFKA_DATA_DIR`
- **По умолчанию:** `/pub/KAFKADATA`
- **Описание:** Директория для данных Kafka

#### `ZOOKEEPER_DATA_DIR`
- **По умолчанию:** `/pub/zookeeper`
- **Описание:** Директория для данных Zookeeper

#### `CRXUI_PORT`
- **По умолчанию:** `9090`
- **Описание:** Порт для Corax UI

#### `CRXSR_PORT`
- **По умолчанию:** `8081`
- **Описание:** Порт для Corax Schema Registry

#### `KFK_VERSION`
- **По умолчанию:** `11.340.0-16`
- **Описание:** Версия дистрибутива KFK (должна соответствовать файлам в `files/`)

---

## Подготовка SSH ключей

### 1. Генерация SSH ключа (если у вас его нет)

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

```bash
# На каждой ноде выполните:
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Добавьте публичный ключ в authorized_keys
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... gitlab-ci-corax
EOF

chmod 600 ~/.ssh/authorized_keys
```

Или используйте `ssh-copy-id`:
```bash
ssh-copy-id -i ~/.ssh/corax_deploy_key.pub root@10.10.11.41  # деплой нода
ssh-copy-id -i ~/.ssh/corax_deploy_key.pub root@10.10.11.42  # рабочая нода 1
ssh-copy-id -i ~/.ssh/corax_deploy_key.pub root@10.10.11.43  # рабочая нода 2
# ... и так далее для всех нод
```

### 3. Добавление приватного ключа в GitLab

```bash
# Скопируйте приватный ключ
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

## Запуск pipeline

### 1. Проверка конфигурации

После настройки всех переменных, убедитесь что:
- ✓ Все ноды доступны по SSH
- ✓ Публичный ключ добавлен на все ноды
- ✓ GitLab Runner активен и доступен
- ✓ Дистрибутивы Corax размещены в директории `files/`

### 2. Запуск pipeline

1. Перейдите в **CI/CD → Pipelines**
2. Нажмите **Run Pipeline**
3. Выберите ветку (например, `main`)
4. Нажмите **Run Pipeline**

### 3. Мониторинг выполнения

Pipeline состоит из 2 stages:

#### Stage 1: `config_generation` (автоматический)
- Генерирует конфигурационные файлы из шаблонов
- Подставляет значения переменных GitLab CI/CD
- Создает артефакты для следующего stage
- Длительность: ~1-2 минуты

#### Stage 2: `node_preparation` (manual)
- Требует ручного подтверждения (кнопка **Play**)
- Подключается к деплой ноде
- Устанавливает необходимые пакеты
- Настраивает окружение для Ansible
- Копирует конфигурационные файлы
- Длительность: ~5-10 минут

**Важно:** Stage `node_preparation` настроен как `when: manual` для безопасности. Перед запуском убедитесь, что конфигурация корректна.

### 4. После успешного выполнения pipeline

1. **Загрузите дистрибутивы на деплой ноду:**
   ```bash
   scp files/*.zip root@10.10.11.41:/pub/corax/files/
   ```

2. **Подключитесь к деплой ноде:**
   ```bash
   ssh root@10.10.11.41
   ```

3. **Запустите развертывание Corax:**
   ```bash
   cd /pub/corax

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

### Ошибка: "SSH connection failed"

**Проблема:** Pipeline не может подключиться к деплой ноде.

**Решение:**
1. Проверьте корректность IP адреса в `DEPLOY_NODE_HOST`
2. Убедитесь, что публичный ключ добавлен в `~/.ssh/authorized_keys` на деплой ноде
3. Проверьте, что SSH сервис запущен: `systemctl status sshd`
4. Проверьте firewall: `iptables -L` или `firewall-cmd --list-all`
5. Попробуйте подключиться вручную: `ssh root@<DEPLOY_NODE_HOST>`

### Ошибка: "apt-get update failed"

**Проблема:** Не удается обновить список пакетов на ALT Linux.

**Решение:**
1. Проверьте настройки репозиториев: `cat /etc/apt/sources.list.d/*`
2. Убедитесь, что нода имеет доступ к интернету или внутренним репозиториям
3. Проверьте DNS: `ping apt.altlinux.org`
4. Попробуйте вручную: `apt-get update -v`

### Ошибка: "Package not found"

**Проблема:** Не найден пакет (например, `openjdk-17-jdk`).

**Решение:**
1. Проверьте версию ALT Linux: `cat /etc/altlinux-release`
2. Для ALT Linux 10.2 пакет может называться иначе:
   - `openjdk-17-jdk` → `java-17-openjdk`
   - Проверьте доступные версии: `apt-cache search openjdk`
3. Обновите pipeline, если необходимо использовать другое имя пакета

### Ошибка: "Ansible ping failed"

**Проблема:** Ansible не может подключиться к рабочим нодам кластера.

**Решение:**
1. Убедитесь, что публичный ключ распространен на все рабочие ноды
2. Проверьте inventory: `cat /pub/corax/inventories/inventory.ini`
3. Проверьте подключение вручную с деплой ноды:
   ```bash
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

### Просмотр логов

Все логи выполнения доступны в GitLab:
1. Перейдите в **CI/CD → Pipelines**
2. Кликните на номер pipeline
3. Кликните на job (например, `generate_configs` или `prepare_deploy_node`)
4. Просмотрите лог выполнения

Для просмотра артефактов:
1. В правой части страницы job нажмите **Browse** или **Download**
2. Просмотрите сгенерированные конфигурационные файлы

---

## Дополнительные ресурсы

- [Документация ALT Linux](https://www.altlinux.org/)
- [Документация Ansible](https://docs.ansible.com/)
- [Документация GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)

---

## Контакты и поддержка

При возникновении проблем:
1. Проверьте раздел [Troubleshooting](#troubleshooting)
2. Просмотрите логи pipeline в GitLab
3. Обратитесь к администратору инфраструктуры

---

**Версия документа:** 1.0
**Дата создания:** 2025-01-12
**Целевая платформа:** ALT Linux 10.2
**Версия Corax:** KFK 11.340.0-16
