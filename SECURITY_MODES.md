# Режимы безопасности кластера Corax

Данный документ описывает доступные режимы безопасности для развертывания кластера Corax и способы их настройки в CI/CD pipeline.

## Обзор

Система поддерживает два режима безопасности:
- **PLAINTEXT** - без шифрования (для dev/test окружений)
- **SSL** - с полным шифрованием и сертификатами (для production окружений)

## Описание режимов

### PLAINTEXT (по умолчанию)

**Файл конфигурации:** `ci/configs/group_vars_plaintext.yaml`

**Назначение:** Режим без шифрования для разработки и тестирования

**Параметры безопасности:**
- `security: PLAINTEXT__ZK_PLAIN_NO_AUTH__KAFKA_PLAINTEXT_NO_AUTH`
- Протокол: PLAINTEXT (без шифрования)
- ZooKeeper: Без аутентификации
- Kafka: Без шифрования и аутентификации
- wait_for_start: 20 секунд
- Сертификаты: Не требуются

**Преимущества:**
- Простая настройка
- Быстрое развертывание
- Не требует сертификатов
- Подходит для локальной разработки

**Недостатки:**
- ❌ Нет шифрования трафика
- ❌ Нет аутентификации
- ❌ НЕ ПОДХОДИТ для production

**Когда использовать:**
- Локальная разработка
- Тестовые окружения
- CI/CD тесты
- Демонстрации на изолированных сетях

---

### SSL

**Файл конфигурации:** `ci/configs/group_vars_ssl.yaml`

**Назначение:** Режим с полным шифрованием для production окружений

**Параметры безопасности:**
- `security: SSL__ZK_mTLS_WITH_AUTH__KAFKA_SSL_WITH_AUTH`
- Протокол: SSL/TLS
- ZooKeeper: mTLS (взаимная аутентификация)
- Kafka: SSL с аутентификацией
- wait_for_start: 120 секунд (увеличено для инициализации SSL)
- Сертификаты: **Обязательны**

**Требуемые сертификаты:**
```
ci/configs/certificates/
├── kafka.keystore.jks   # Хранилище приватного ключа и сертификата
└── kafka.truststore.jks # Хранилище доверенных CA сертификатов
```

**Пути сертификатов на целевых нодах:**
- KeyStore: `/pub/opt/Apache/kafka/ssl/kafka.keystore.jks`
- TrustStore: `/pub/opt/Apache/kafka/ssl/kafka.truststore.jks`

**Пароли сертификатов:**
Настраиваются в `ci/variables.yml`:
```yaml
SSL_KEYSTORE_PASSWORD: "changeit"
SSL_TRUSTSTORE_PASSWORD: "changeit"
SSL_KEY_PASSWORD: "changeit"
```

**⚠️ ВАЖНО для Production:**
- Используйте сложные пароли!
- Храните пароли в GitLab CI/CD Variables с типом "Masked"
- Никогда не коммитьте пароли в git!

**Преимущества:**
- ✅ Полное шифрование трафика
- ✅ Взаимная аутентификация (mTLS)
- ✅ Соответствие требованиям безопасности
- ✅ Подходит для production

**Недостатки:**
- Требует создания и управления сертификатами
- Более длительная инициализация
- Сложнее в отладке

**Когда использовать:**
- Production окружения
- Окружения с чувствительными данными
- Развертывание в DMZ
- Соответствие compliance требованиям (PCI DSS, GDPR, etc.)

---

## Использование

### При ручном запуске pipeline через GitLab UI

1. Перейдите в **CI/CD → Pipelines**
2. Нажмите **Run Pipeline**
3. В выпадающем списке **CLUSTER_SECURITY_MODE** выберите режим:
   - `plaintext` (по умолчанию)
   - `ssl`
4. Нажмите **Run Pipeline**

### При запуске через API

```bash
curl -X POST \
  -F token=YOUR_TRIGGER_TOKEN \
  -F ref=main \
  -F "variables[CLUSTER_SECURITY_MODE]=ssl" \
  https://gitlab.com/api/v4/projects/PROJECT_ID/trigger/pipeline
```

### Через переменные GitLab CI/CD

1. Перейдите в **Settings → CI/CD → Variables**
2. Найдите или создайте переменную `CLUSTER_SECURITY_MODE`
3. Установите значение: `plaintext` или `ssl`
4. Для SSL режима также настройте (тип "Masked"):
   - `SSL_KEYSTORE_PASSWORD`
   - `SSL_TRUSTSTORE_PASSWORD`
   - `SSL_KEY_PASSWORD`
5. Сохраните изменения

### В коде (ci/variables.yml)

Измените значение по умолчанию:
```yaml
CLUSTER_SECURITY_MODE: "plaintext"  # или "ssl"
```

---

## Подготовка SSL сертификатов

### Генерация самоподписанных сертификатов (для тестирования)

```bash
# 1. Создание приватного ключа и keystore
keytool -genkey -alias kafka-server \
  -keyalg RSA -keysize 2048 \
  -keystore kafka.keystore.jks \
  -storepass changeit \
  -keypass changeit \
  -dname "CN=kafka.local,OU=IT,O=Company,L=City,ST=State,C=US" \
  -validity 365

# 2. Экспорт сертификата
keytool -export -alias kafka-server \
  -keystore kafka.keystore.jks \
  -rfc -file kafka-cert.pem \
  -storepass changeit

# 3. Создание truststore и импорт сертификата
keytool -import -alias kafka-ca \
  -file kafka-cert.pem \
  -keystore kafka.truststore.jks \
  -storepass changeit \
  -noprompt
```

### Размещение сертификатов в репозитории

```bash
# Скопируйте сертификаты в репозиторий
cp kafka.keystore.jks ci/configs/certificates/
cp kafka.truststore.jks ci/configs/certificates/

# Проверка
ls -lh ci/configs/certificates/
```

⚠️ **ВАЖНО:**
- Сертификаты в репозитории должны быть защищены
- Рассмотрите использование GitLab File Variables для production
- Регулярно обновляйте сертификаты перед истечением срока действия

### Использование CA-подписанных сертификатов (production)

Для production рекомендуется использовать сертификаты, подписанные корпоративным CA:

1. Создайте CSR (Certificate Signing Request):
```bash
keytool -certreq -alias kafka-server \
  -keystore kafka.keystore.jks \
  -file kafka.csr \
  -storepass changeit
```

2. Отправьте CSR в ваш CA для подписи

3. Получите подписанный сертификат и импортируйте его:
```bash
# Импорт корневого CA сертификата
keytool -import -alias ca-root \
  -file ca-root.pem \
  -keystore kafka.keystore.jks \
  -storepass changeit

# Импорт подписанного сертификата
keytool -import -alias kafka-server \
  -file kafka-signed.pem \
  -keystore kafka.keystore.jks \
  -storepass changeit
```

---

## Валидация конфигурации

Перед запуском pipeline рекомендуется проверить конфигурацию:

```bash
# Установите переменную окружения
export CLUSTER_SECURITY_MODE="ssl"

# Запустите скрипт валидации
bash ci/scripts/validate_security_mode.sh
```

Скрипт проверит:
- Корректность режима безопасности
- Наличие файла конфигурации
- Наличие сертификатов (для SSL режима)
- Размер файлов сертификатов

---

## Сравнительная таблица

| Параметр | PLAINTEXT | SSL |
|----------|-----------|-----|
| **Протокол** | PLAINTEXT | SSL/TLS |
| **Шифрование** | Нет ❌ | Да ✅ |
| **Аутентификация** | Нет ❌ | mTLS ✅ |
| **Сертификаты** | Не требуются | Обязательны |
| **wait_for_start** | 20 сек | 120 сек |
| **cleanLog (kafka)** | false | true |
| **cleanData (kafka)** | false | true |
| **Сложность настройки** | Низкая | Средняя |
| **Производительность** | Высокая | Средняя |
| **Безопасность** | Низкая ❌ | Высокая ✅ |
| **Production ready** | Нет ❌ | Да ✅ |

---

## Логирование и отладка

### Логи pipeline

В логах GitLab CI/CD вы увидите:

```
========================================
ВАЛИДАЦИЯ РЕЖИМА БЕЗОПАСНОСТИ
========================================

Выбранный режим: ssl

✓ Режим безопасности валиден

=== Проверка SSL сертификатов ===
✓ SSL сертификаты найдены
  - kafka.keystore.jks (2048 bytes)
  - kafka.truststore.jks (1024 bytes)

--- Описание режима 'ssl' ---
Режим с полным шифрованием
- Протокол: SSL/TLS
- ZooKeeper: mTLS с аутентификацией
- Kafka: SSL с аутентификацией
- Сертификаты: Требуются JKS файлы
- Назначение: Production окружения
- wait_for_start: 120 секунд
```

### Проверка на деплой ноде

После развертывания проверьте конфигурацию:

```bash
# Подключитесь к деплой ноде
ssh root@deploy-node

# Проверка наличия конфигурации безопасности
cat /pub/corax/files/group_vars_all.j2 | grep security

# Для SSL режима - проверка сертификатов
ls -la /pub/corax/files/*.jks

# Проверка содержимого keystore
keytool -list -keystore /pub/corax/files/kafka.keystore.jks \
  -storepass changeit
```

---

## Troubleshooting

### Проблема: Pipeline падает на валидации SSL

**Симптом:**
```
❌ ERROR: Отсутствует файл ci/configs/certificates/kafka.keystore.jks
```

**Решение:**
1. Убедитесь, что сертификаты размещены в `ci/configs/certificates/`
2. Проверьте имена файлов (должны быть `kafka.keystore.jks` и `kafka.truststore.jks`)
3. Убедитесь, что файлы закоммичены в git

### Проблема: Сертификаты слишком малы

**Симптом:**
```
⚠️  WARNING: Файл kafka.keystore.jks слишком мал (64 bytes)
Возможно, это заглушка
```

**Решение:**
Замените placeholder файлы на реальные JKS сертификаты (см. раздел "Подготовка SSL сертификатов")

### Проблема: Kafka не запускается в SSL режиме

**Симптом:**
- Kafka не проходит проверку wait_for_start
- В логах ошибки SSL handshake

**Решение:**
1. Проверьте пароли сертификатов в переменных GitLab
2. Убедитесь, что сертификаты корректные:
```bash
keytool -list -keystore kafka.keystore.jks -storepass ВАШПАРОЛЬ
```
3. Проверьте логи Kafka на целевых нодах:
```bash
tail -f /pub/opt/Apache/kafka/logs/server.log
```

### Проблема: Несоответствие паролей

**Симптом:**
```
ERROR: Keystore was tampered with, or password was incorrect
```

**Решение:**
Убедитесь, что пароли в `ci/variables.yml` соответствуют паролям, использованным при создании сертификатов

---

## Комбинирование с вариантами конфигурации

Режим безопасности работает независимо от варианта конфигурации кластера:

| Комбинация | Описание |
|------------|----------|
| `plaintext + standard` | Dev окружение с стандартными настройками |
| `plaintext + alternative` | Test окружение с увеличенными таймаутами |
| `plaintext + custom` | Debug окружение с полной очисткой |
| `ssl + standard` | ✅ **Рекомендуется для production** |
| `ssl + alternative` | Staging с SSL и расширенным логированием |
| `ssl + custom` | Debug production проблем с SSL |

---

## Best Practices

### Для Development/Test окружений:
1. Используйте режим `plaintext`
2. Не храните sensitive данные
3. Изолируйте тестовую сеть

### Для Production окружений:
1. **Обязательно** используйте режим `ssl`
2. Используйте CA-подписанные сертификаты
3. Храните пароли в GitLab CI/CD Variables (тип "Masked")
4. Настройте автоматическое обновление сертификатов
5. Регулярно проводите security audit
6. Включите мониторинг истечения сертификатов
7. Документируйте процесс обновления сертификатов

### Управление сертификатами:
1. Используйте централизованное хранилище сертификатов
2. Автоматизируйте процесс обновления
3. Ведите реестр сертификатов и сроков их действия
4. Настройте алерты на истечение срока действия (за 30 дней)

---

## Миграция с PLAINTEXT на SSL

Если вы уже развернули кластер в режиме PLAINTEXT и хотите мигрировать на SSL:

1. Создайте и протестируйте сертификаты
2. Разверните новый кластер в SSL режиме
3. Настройте репликацию данных (если требуется)
4. Переключите клиентов на новый кластер
5. Проведите тестирование
6. Выведите старый кластер из эксплуатации

⚠️ **ВАЖНО:** Прямая миграция существующего кластера требует остановки сервисов и изменения конфигураций на всех нодах.

---

## Поддержка

Для вопросов и проблем:
- Проверьте логи pipeline в GitLab CI/CD
- Запустите скрипты валидации локально
- Изучите документацию CONFIG_VARIANTS.md
- См. также: GITLAB_SETUP.md, README.md

---

**Последнее обновление:** 2025-11-17
**Версия документа:** 1.0
