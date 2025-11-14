# Варианты конфигурации кластера Corax

Данный документ описывает доступные варианты конфигурации кластера Corax и способы их использования в CI/CD pipeline.

## Обзор

Система поддерживает три варианта конфигурации кластера:
- **Standard** - стандартная конфигурация для production окружения
- **Alternative** - альтернативная конфигурация для тестового окружения
- **Custom** - кастомная конфигурация для отладки и разработки

## Описание вариантов

### Standard (по умолчанию)

**Файл конфигурации:** `files/group_vars_all_standard.j2`

**Назначение:** Стандартная конфигурация для production окружения

**Параметры:**
- `wait_for_start: 20` - стандартное время ожидания запуска приложения (20 секунд)
- `tmp_dir: /tmp/installer` - стандартная временная директория
- `kafka.cleanLog: false` - логи не удаляются при установке
- `kafka.cleanData: false` - данные Kafka сохраняются
- `zookeeper.cleanLog: false` - логи ZooKeeper не удаляются
- `zookeeper.cleanData: false` - данные ZooKeeper сохраняются

**Когда использовать:**
- Для production развертывания
- Когда важна стабильность и надежность
- При обновлении существующего кластера с сохранением данных

---

### Alternative

**Файл конфигурации:** `files/group_vars_all_alternative.j2`

**Назначение:** Альтернативная конфигурация с увеличенными таймаутами для тестового окружения

**Параметры:**
- `wait_for_start: 30` - увеличенное время ожидания запуска (30 секунд)
- `tmp_dir: /tmp/installer` - стандартная временная директория
- `kafka.cleanLog: false` - логи не удаляются
- `kafka.cleanData: false` - данные Kafka сохраняются
- `zookeeper.cleanLog: false` - логи ZooKeeper не удаляются
- `zookeeper.cleanData: true` - данные ZooKeeper очищаются при установке ⚠️

**Когда использовать:**
- Для тестового окружения
- При развертывании на медленном оборудовании
- Когда требуется очистка данных ZooKeeper при каждой установке
- Для тестирования с чистой конфигурацией ZooKeeper

---

### Custom

**Файл конфигурации:** `files/group_vars_all_custom.j2`

**Назначение:** Кастомная конфигурация для отладки и разработки

**Параметры:**
- `wait_for_start: 60` - максимальное время ожидания запуска (60 секунд)
- `tmp_dir: /tmp/installer_custom` - кастомная временная директория
- `kafka.logdir: /pub/opt/Apache/kafka/logs_custom` - кастомная директория логов
- `kafka.datadir: /pub/KAFKADATA_custom` - кастомная директория данных
- `kafka.cleanLog: true` - логи Kafka очищаются при каждой установке ⚠️
- `kafka.cleanData: true` - данные Kafka очищаются при каждой установке ⚠️
- `zookeeper.logdir: /pub/opt/Apache/kafka/logs_custom` - кастомная директория логов
- `zookeeper.datadir: /pub/zookeeper_custom` - кастомная директория данных
- `zookeeper.cleanLog: true` - логи ZooKeeper очищаются ⚠️
- `zookeeper.cleanData: true` - данные ZooKeeper очищаются ⚠️
- `crxsr.cleanLog: true` - логи CRXSR очищаются ⚠️
- `crxui.cleanLog: true` - логи CRXUI очищаются ⚠️
- `crxui.cleanData: true` - данные CRXUI очищаются ⚠️

**Когда использовать:**
- Для разработки и отладки
- При тестировании чистой установки
- Когда нужно полностью очистить все данные и логи
- Для изоляции от production конфигурации (кастомные пути)

⚠️ **ВНИМАНИЕ:** Этот вариант **полностью очищает все данные и логи** при каждой установке! Не используйте в production!

---

## Использование

### При ручном запуске pipeline через GitLab UI

1. Перейдите в **CI/CD → Pipelines**
2. Нажмите **Run Pipeline**
3. В выпадающем списке **CLUSTER_CONFIG_VARIANT** выберите нужный вариант:
   - `standard`
   - `alternative`
   - `custom`
4. Нажмите **Run Pipeline**

### При запуске через API

Используйте параметр `variables[CLUSTER_CONFIG_VARIANT]`:

```bash
curl -X POST \
  -F token=YOUR_TRIGGER_TOKEN \
  -F ref=main \
  -F "variables[CLUSTER_CONFIG_VARIANT]=alternative" \
  https://gitlab.com/api/v4/projects/PROJECT_ID/trigger/pipeline
```

### Через переменные GitLab CI/CD

1. Перейдите в **Settings → CI/CD → Variables**
2. Найдите или создайте переменную `CLUSTER_CONFIG_VARIANT`
3. Установите значение: `standard`, `alternative` или `custom`
4. Сохраните изменения

### В коде (ci/variables.yml)

Измените значение по умолчанию в файле `ci/variables.yml`:

```yaml
CLUSTER_CONFIG_VARIANT: "standard"  # или "alternative", или "custom"
```

---

## Валидация конфигурации

Перед использованием варианта конфигурации рекомендуется выполнить валидацию:

```bash
# Установите переменную окружения
export CLUSTER_CONFIG_VARIANT="alternative"

# Запустите скрипт валидации
bash ci/scripts/validate_config_variant.sh
```

Скрипт проверит:
- Корректность названия варианта
- Наличие файла конфигурации
- Выведет описание выбранного варианта

---

## Структура файлов

```
files/
├── group_vars_all.j2               # Резервный вариант (используется если выбранный не найден)
├── group_vars_all_standard.j2      # Вариант 1: Standard
├── group_vars_all_alternative.j2   # Вариант 2: Alternative
└── group_vars_all_custom.j2        # Вариант 3: Custom
```

---

## Добавление нового варианта

Чтобы добавить новый вариант конфигурации:

1. **Создайте новый файл конфигурации:**
   ```bash
   cp files/group_vars_all_standard.j2 files/group_vars_all_myvariant.j2
   ```

2. **Отредактируйте параметры** в файле `files/group_vars_all_myvariant.j2`

3. **Добавьте вариант в .gitlab-ci.yml:**
   ```yaml
   workflow:
     rules:
       - if: $CI_PIPELINE_SOURCE == "web"
         variables:
           CLUSTER_CONFIG_VARIANT:
             value: "standard"
             description: "Выберите вариант конфигурации кластера"
             options:
               - "standard"
               - "alternative"
               - "custom"
               - "myvariant"  # <-- добавьте здесь
   ```

4. **Обновите скрипт валидации** `ci/scripts/validate_config_variant.sh`:
   ```bash
   VALID_VARIANTS="standard alternative custom myvariant"
   ```

5. **Обновите документацию** в этом файле

---

## Логирование и отладка

При выполнении playbook вы увидите:

```
TASK [Debug - показать выбранный вариант конфигурации]
ok: [corax-node1] => {
    "msg": "Используется вариант конфигурации кластера: alternative"
}
```

В логах GitLab CI/CD будет выведено:

```
Деплой нода - 10.10.11.41
Пользователь - root
Целевая директория - /corax/corax_prepare
Архив - /test-distribs/corax_prepare.zip
Вариант конфигурации кластера - alternative
```

---

## Сравнительная таблица

| Параметр | Standard | Alternative | Custom |
|----------|----------|-------------|--------|
| **wait_for_start** | 20 сек | 30 сек | 60 сек |
| **tmp_dir** | /tmp/installer | /tmp/installer | /tmp/installer_custom |
| **kafka.cleanLog** | false | false | true ⚠️ |
| **kafka.cleanData** | false | false | true ⚠️ |
| **zookeeper.cleanLog** | false | false | true ⚠️ |
| **zookeeper.cleanData** | false | true ⚠️ | true ⚠️ |
| **Пути** | стандартные | стандартные | кастомные |
| **Назначение** | Production | Тестирование | Отладка |

⚠️ - Данные и/или логи будут удалены при установке

---

## Поддержка

Для вопросов и проблем:
- Изучите логи pipeline в GitLab CI/CD
- Проверьте валидацию конфигурации
- Ознакомьтесь с файлами конфигурации в директории `files/`
- См. также: `GITLAB_SETUP.md`, `README.md`

---

**Последнее обновление:** 2025-11-14
