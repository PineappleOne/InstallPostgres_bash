#!/bin/bash

set -Eeuo pipefail


databaseName=""

#Функции---------------------------------------------------

deleteDB()
{
	echo "🚨 Удаление БД postgresql"
	apt-get --purge  -y remove postgresql postgresql-*  
	clear
	echo -e "✅ Удаление завершено\n"
}

updatePackages()
{
	echo "🚀 Обновление пакетов"
	apt-get update &> /dev/null
}

installPostgres()
{
	echo "🚀 Установка Postgres"
	apt-get install -y postgresql &> /dev/null
	echo -e "✅ Установка завершена"
	echo "Установленна версия:"
	pg_config --version
	echo " "
}

setLocale()
{
	echo -e "⏰ Установка кодировки и тайм зоны (Москва) \n"
	localectl set-locale LANG=ru_RU.utf8
	timedatectl set-timezone Europe/Moscow
}

configureHba()
{
	echo "🚦Конфигурирование файла pg_hba.conf"
	myIP=`ip -4 addr show eth0 | grep -oP "(?<=inet ).*(?=/)"`
	echo "  * IP:$myIP"
	echo "  * Backup pg_hba.conf"
	cp -v /etc/postgresql/12/main/pg_hba.conf /etc/postgresql/12/main/pg_hbaconf.bac &> /dev/null
	
	echo "host    postgressql     postgres             $myIP                trust" >> /etc/postgresql/12/main/pg_hba.conf
	echo "host    postgressql     postgres             192.168.1.100               trust" >> /etc/postgresql/12/main/pg_hba.conf
	echo -e "✅ Конфигурирование файла pg_hba.conf завершено\n"
}

createDbAndBackup()
{
	local databaseName=$1
	echo "🚦Создание бд $databaseName и Backup"
	sudo -u postgres psql -c "create database $databaseName;" &> /dev/null
	mkdir Backups -p
	sudo -u postgres pg_dump $databaseName | gzip > Backups/$databaseName.dump.gz
	echo -e "✅ Бэкап: Backups/$databaseName.dump.gz\n"
}

createSchemaAndTables()
{
	echo "🚦Создание схем и таблиц"
	local databaseName=$1
	schemaName=`printf "%s_schema" $databaseName`
	sudo -u postgres psql -c "CREATE SCHEMA $schemaName" &> /dev/nul
	
	table_names=($databaseName"_Table1" $databaseName"_Table2" $databaseName"_Table3" )
	for i in ${table_names[@]}
	do
		sudo -u postgres psql -c "CREATE TABLE $i (id serial primary key, name varchar(255));" &> /dev/null
		echo "  * Создана таблица $i"
	done
	echo -e "✅ Созданы схема и таблицы\n"
}

createRoleAndGrant()
{
	echo "🚦Создание ролей и выдача прав"
	
	local databaseName=$1
	local schemaName=`printf "%s_schema" $databaseName`
	{
		sudo -u postgres psql -c "CREATE ROLE dba with createdb login password 'dba';" 
		sudo -u postgres psql -c "grant all privileges on database $databaseName to dba;" 
	
		sudo -u postgres psql -c "CREATE ROLE api with login password 'api' connection limit 1000;" 
		sudo -u postgres psql -c "grant SELECT,UPDATE,INSERT on ALL TABLES IN SCHEMA $schemaName to api;" 
	} &> /dev/null
	echo -e "✅ Роли и права созданы\n"
}

usage()
{
	echo "---------------------------------"
	echo "Описание: данный скрипт выполняет установку СУБД Postgres  "
	echo "Алгоритм:  "
	echo "  1)Обновление пакетов и установка БД "
	echo "  2)Конфигурирование hba "
	echo "  3)Создание базы данных и первичный бэкап "
	echo "  4)Создание тестовых таблиц "
	echo "  5)Установка ролей и прав "
	echo "Аргументы: "
	echo "  Первый аргумент: "
	echo "    -H Выводит справку о скрипте "
	echo "    -I Устанавлиет и конфигурирует СУБД "
	echo "    -D Устанавлиет и конфигурирует СУБД "
	echo "  Второй аргумент: "
	echo "    Желаемое наименование БД "
	echo "--------------------------------- "
}

#----------------------------------------------------------


if [[ $# == 0 ]];
then
	echo "Введите первый параметр скрипта (-D для удаления бд, -I для установки)"
	exit 1;
fi

if [[ "$1" == "-H" ]]; then
	usage
	exit 0
fi

if [[ $# > 1 ]]
then
	databaseName=$2
else
	databaseName="nonamed_bd"
fi


if [[ "$1" == "-D" ]]
then
	deleteDB
else
	echo " "

	updatePackages
	installPostgres
	setLocale
	configureHba
	createDbAndBackup $databaseName
	createSchemaAndTables $databaseName
	createRoleAndGrant $databaseName

	echo "🎉 Скрипт успешно закончил работу"
fi


exit 0;

