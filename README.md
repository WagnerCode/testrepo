Данный проект - это подготовительный этап развертывания Corax-системы. Он готовит дистрибутивы ПО, распаковывает, модифицирует и подготавливает к установке с помощью Ansible.

playbook.yaml 
Этот плейбук — подготовительный этап (bootstrap) для развёртывания системы Corax. Он настраивает хост, копирует артефакты, запускает prepare.sh и подготавливает структуру для основного развёртывания. 

Некоторые ключевые этапы:

/pub/corax/tmp/ — временное хранилище, /pub/corax — основная директория Corax
Запуск prepare.sh
prepare.sh: 
    Извлекает и запускает restore-distrib-1.0.1.sh → восстанавливает дистрибутив.
    Распаковывает KFKA, kfka-deploy.
    Копирует distrib.zip в ../files/ (но это может быть проблемой, см. ниже).
    Патчит Ansible-роли.
    Копирует .jar в /tmp.
Создание структуры для инвентаря Corax;
Генерация group_vars/all.yaml;
Генерация inventory.ini;
Копирование подплейбуков.


---
Corax поставляется в виде ZIP-архива, который разделен на:

архив с компонентами продукта в ZIP-формате с именем *-owned*.zip; содержит архивы с конфигурациями и бинарными артифактами компонентов;
архив с внешними opensource-зависимостями в ZIP-формате с именем *-party*.zip; основная часть — opensource-библиотеки;
архив с документацией в ZIP-формате с именем *-doc*.zip; основная часть — документация и метаинформация.
Для получения дистрибутива, необходимого для дальнейшей инсталляции, необходимо воспользоваться :

bash restore-distrib*.sh -d KFK-10.340.0-16-distrib.zip

На выходе мы получим архив с восстановленным дистрибутивом KFK-12.381.1-16.zip

Шаги, описанные выше, были автоматизированы при помощи плейбука, который лежит на REDOS installer (в corax_prepare):

необходимо убедиться, что версия того дистрибутива, который инсталлируется, совпадает со значениями, указанными в prepare.sh и playbook.yaml
задать нужные значения remote_user и private_key_file в corax_prepare/ansible.cfg
задать ip хоста в corax_prepare/inventory.ini
убедиться, что мы закинули public key в authorized_keys, учетной записи, которую указали в переменной ansible_user

# cd ~/corax/corax_prepare
# ansible-playbook -i inventory.ini playbook.yaml


Хост на который будет разворачиваться дистрибутив(плейбуком из corax_prepare), cодержащий плейбуки для инсталляции Corax (шаг №0)
10.10.11.41

Наша группа хостов, куда будет инсталлироваться Corax(пример):
10.10.11.41
10.10.11.42
10.10.11.43

В данном случае мы должны закинуть public_key с 10.10.11.41 на наши хосты 10.10.11.42 и 10.10.11.43 в /root/.ssh/authorized_keys
Также выдать для пользователя root права на исполнение sudo


---
Дальнейшие шаги после установки данного плейбука
# cd /pub/corax
# ansible-playbook -i inventories/inventory.ini prepare_corax.yaml
# ansible-playbook -i inventories/inventory.ini playbooks/kafka-zookeeper-SE.yml -t enabled_service
# ansible-playbook -i inventories/inventory.ini playbooks/kafka-zookeeper-SE.yml 
# ansible-playbook -i inventories/inventory.ini playbooks/crxsr.yml -t root,install,start
# ansible-playbook -i inventories/inventory.ini playbooks/crxui.yml -t root,install
# ansible-playbook -i inventories/inventory.ini post_install_corax.yaml
