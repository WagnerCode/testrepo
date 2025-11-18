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
