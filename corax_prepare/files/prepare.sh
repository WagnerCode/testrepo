#!/bin/bash
KFK_version=11.340.0-16
rm -rf $(ls|grep -sw 'restore')
unzip $(find -name 'corax*') 'restore*.sh'
chmod +x $(ls|grep -sw 'restore')
./$(ls|grep -sw 'restore') -d KFK-$KFK_version-distrib.zip
unzip  KFK-$KFK_version.zip 'KFKA*.zip'
unzip  KFKA-$KFK_version-distrib.zip 'kfka-deploy*'
unzip  kfka-deploy-$(echo $KFK_version|cut -d- -f1)-distrib.zip -d ../
cp KFKA-$KFK_version-distrib.zip ../files/distrib.zip

unzip "ansible_corax_json_exporter.zip" -d ../../

#FIX PLAYBOOK
sed -i 's/crx-ui-start {{ crxui.installdir/crx-ui-start -daemon {{ crxui.installdir/' ../roles/crxui/tasks/main.yml
cp ../files/password-encrypt-cli-2.4.0.jar /tmp/password-encrypt-cli-2.4.0.jar
