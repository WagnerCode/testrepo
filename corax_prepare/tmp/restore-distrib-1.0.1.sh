#!/usr/bin/env bash
set -o nounset; set -o errexit; set -o pipefail; set -o errtrace; set -o functrace



#
# ИСТОРИЯ ИЗМЕНЕНИЙ
#
# v1.0
#  (+) Релиз



#
# ПЕРЕМЕННЫЕ
#
DIR__SCRIPT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" # директория со скриптом
DISTRIB_LIST=( "IGN" "KFK" )                                            # список поддерживаемых дистрибутивов
PROGRAM_LIST=( "grep" "sed" "awk" "unzip" "zip" "jq" )                  # список требуемого ПО для запуска скрипта

path_to_distrib=""      # путь до архива с разобранным дистрибутивом
work_dir=""             # путь до рабочего каталога, откуда будет происходить сборка
temp_dir=""             # путь до рабочего каталога, где будет происходить сборка
restore_archive_list=() # список путей до директорий для обратной упаковки



#
# ФУНКЦИИ
#
## Инструкция по использованию
usage() {
    local errorMessage="${1:-}"

    if [[ -n "${errorMessage}" ]]; then echo "[ОШИБКА] ${errorMessage}"; echo; fi

    cat << EOF
Скрипт восстановления дистрибутивов после разделения на внутренние и внешние библиотеки
Версия: 1.0
Разработка: Иванов Петр <PSergeIvanov@sberbank.ru>


Использование: bash ${BASH_SOURCE[0]} <PARAMS>

Параметры:
    -d, --distrib <path_to_distrib>  путь до архива с дистрибутивом
EOF

    exit 1
}


## Сбор строки с разделителем из массива
join_by() {
    local IFS="${1}"

    shift
    echo "$*"
}


## Проверка окружения перед запуском
checkEnv() {
    echo "### ПРОВЕРКА ОКРУЖЕНИЯ ###"

    # Проверка на наличие необходимых программ для запуска скрипта
    for program in "${PROGRAM_LIST[@]}"; do
        echo -n " * Поиск '${program}'... "
        type "${program}" >/dev/null 2>&1 || {
            echo "[ОШИБКА] Требуемая программа '${program}' не найдена."
            exit 1
        }
        echo "[OK]"
        sleep 0.1
    done

    # Проверка на версию 'sed'
    echo -n " * Проверка версии 'sed'... "
    sed --version 2>/dev/null | grep -q GNU || {
        echo "[ОШИБКА] Версия sed не GNU"
        exit 1
    }
    echo "[OK]"

    echo
}


## Анализ и обработка переданных параметров
parseArgs() {
    local valid_distrib # признак работы с поддерживаемым дистрибутивом

    # Помощь по скрипту
    if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then usage; fi

    # Разбор параметров и опций к скрипту
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -d | --distrib) path_to_distrib="${2}"; shift 2  ;;
            *)              usage "Неизвестная опция '${1}'" ;;
        esac
    done

    # Валидация параметров | конфгурация скрипта на основе переданных параметров
    if [[ "${path_to_distrib}" == "" ]]; then
        usage "Отсутствует обязательный параметр 'путь до архива с дистрибутивом'"
    fi

    for distrib in "${DISTRIB_LIST[@]}"; do
        if [[ "$(basename "${path_to_distrib}")" =~ ^${distrib} ]]; then
            valid_distrib=true
            temp_dir="${distrib}"
            break
        fi
    done
    if [[ "${valid_distrib:-}" != "true" ]]; then
        echo "[ОШИБКА] Неподдерживаемый тип дистрибутива. Поддерживаются только $(join_by ',' "${DISTRIB_LIST[@]}" | sed -r "s|,|, |")"
        exit 1
    fi

}


## Распаковка дистрибутива
unpackDistrib() {
    echo "### РАСПАКОВКА ДИСТРИБУТИВА ###"

    # Распаковка дистрибутива рядом с архивом (по тому же пути) с перезаписью файлов по умолчанию
    echo -n " * Распаковка '${path_to_distrib}'... "
    work_dir="$(basename "${path_to_distrib%.zip}")"
    unzip -qo -d "${path_to_distrib%.zip}" "${path_to_distrib}" && echo "[OK]"

    # Распаковка OWNED части дистрибутива в текущую директорию
    echo -n " * Распаковка '$(ls "${work_dir}"/*owned*.zip)'... " 
    unzip -qo -d "${temp_dir}" "${work_dir}"/*owned*.zip && echo "[OK]"

    echo
}


## Восстановление файлов
restoreDistrib() {
    local hash_sum             # хэш-сумма восстанавливаемого файла
    local hash_sum_file        # файл с именем хэш-суммы
    local file_paths           # список путей для восстановления
    local file_path_list       # массив с путями для восстановления
    local dir_path             # путь до файла для восстановления
    local partial_dir_path     # часть пути до файла для восстановления
    local old_partial_dir_path # предыдущая часть пути до файла для восстановления

    echo "### ВОССТАНОВЛЕНИЕ ДИСТРИБУТИВА ###"

    cd "${temp_dir}"

    # Поиск инвентори файла и парсинг на предмет подготовки массива с данными о хешах и путях
    # (!) Требуется применение дополнительных преобразований, так как Report.json поставляется битым (с многостроковыми значениями без переносов)
    readarray -t files_to_restore_list < <( \
        sed -r -e 's|^\s+||' < "Report.json" | \
        sed -r ':a;N;$!ba;s/\n/ /g' | \
        jq -r '.party[] | "\(.sha1):\(.files | join(";"))"'
    )

    i=1
    for file in "${files_to_restore_list[@]}"; do
        # Парсинг данных из Report.json для получения хэш-суммы восстанавливаемого файла и путей куда необходимо восстановить
        IFS=':' read -r hash_sum file_paths <<< "${file}"
        IFS=';' read -r -a file_path_list <<< "${file_paths}"

        # Извлечение файла по хэш-сумме
        hash_sum_file="$(unzip -l "../${work_dir}"/*party*.zip | grep "${hash_sum}" | awk '{print $4}')"
        echo " * [$(printf "%$(awk '{print length}' <<< ${#files_to_restore_list[@]})d" ${i}) из ${#files_to_restore_list[@]}] Восстановление файла '${hash_sum_file}':"
        for item in "${file_path_list[@]}"; do
            echo -n "    - ${item}... "

            # Проверка на то, что путь для восстановления файла существует
            dir_path="$(dirname "${item}")"
            while [[ ! -d "${dir_path}" ]]; do
                partial_dir_path="${dir_path}"

                # Поиск архивов в пути до восстанавливаемого файла
                old_partial_dir_path=""
                while [ ! -d "${partial_dir_path}" ] && [ "${partial_dir_path}" != "${old_partial_dir_path}" ]; do
                    old_partial_dir_path="${partial_dir_path}"
                    partial_dir_path="$(sed -r "s|(.*)/.*|\1|" <<< "${partial_dir_path}")"
                done

                # Распаковка архива в директорию с названием архива
                unzip -q -d "${old_partial_dir_path}.dir" "${old_partial_dir_path}"
                rm -rf "${old_partial_dir_path}"
                mv "${old_partial_dir_path}.dir" "${old_partial_dir_path}"
                restore_archive_list=( "${old_partial_dir_path}" "${restore_archive_list[@]}" )
            done

            # Восстановление файла
            unzip -p "$(ls "../${work_dir}"/*party*.zip)" "${hash_sum_file}" > "${item}" && echo "[OK]"
        done

        ((i=i+1))
    done

    cd "${DIR__SCRIPT}"

    echo
}


## Упаковка дистрибутива с распакованными промежуточными архивами
repackDistrib() {
    local distrib_name # название архива с упакованным дистрибутивом

    echo "### УПАКОВКА ДИСТРИБУТИВА ###"

    cd "${temp_dir}"

    # Упаковка директорий в архив с названием директории
    for file in "${restore_archive_list[@]}"; do
        echo -n " * ${file}... "
        mv "${file}" "${file}.dir"
        cd "${file}.dir"
        zip -0 -qr "../$(basename "${file}")" ./* && echo "[OK]"
        cd "${OLDPWD}"
        rm -rf "${file}.dir"
    done

    # Упаковка финального дистрибутива
    rm -rf ./*.json
    distrib_name="$(sed -r 's|-distrib||' < <(basename "${path_to_distrib}"))"
    echo -n " * ${distrib_name}... "
    zip -qrFS "../${distrib_name}" ./ && echo "[OK]"
    echo; echo "ℹ️ Архив с восстановленным дистрибутивом доступен здесь: ${DIR__SCRIPT}/${distrib_name}"

    cd "${DIR__SCRIPT}"

    echo
}


## Удаление временных рабочих файлов
cleanUp() {
    echo "### ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ ###"

    # Очистка файлов
    for file in "${work_dir}" "${temp_dir}"; do
        if [[ "${file}" != "" ]]; then
            echo -n " * ${file}... "
            rm -rf "${DIR__SCRIPT:?}/${file}" && echo "[OK]"
        fi
    done

    echo
}


## Обработка выходов из программы
processTrap() {
    local exit=${1}

    if [[ "${exit}" -ne 0 ]]; then
        echo; echo
    fi
    cleanUp
}


## Основная программа
main() {
    ## Проверка окружения перед запуском
    checkEnv

    ## Анализ и обработка переданных параметров
    parseArgs "$@"

    # ## Обработка сигналов выхода
    trap 'exit 1' INT
    trap 'processTrap $?' EXIT


    ## Распаковка дистрибутива
    unpackDistrib


    ## Восстановление файлов
    restoreDistrib


    ## Упаковка дистрибутива
    repackDistrib
}



#
# СТАРТ
#
main "$@"
