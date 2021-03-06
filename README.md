# ZABBIX WITH PARTITION TABLES

## History

Some time ago I was working and involved in some proyects conformed by several servers each one, that servers had to be monitored and after search and review some OpenSource proyects like [Zabbix](https://www.zabbix.com/), [Nagios](https://www.nagios.org/), [Cacti](https://www.cacti.net/) and so on I decided to use Zabbix to implement monitoring and alerting tasks, I liked Zabbix so much because it store collected data into a PostgreSQL database and that offered another advantage for me because I was interested in store that data for a long time period and use it to leverage capacity planing effors. Then I had to modify Zabbix database schema to adapt it for partition tables use and aditionally implement tablespaces.

Implement partition tables and tablespaces bring some advantages to leverage database performance because it makes possible store data and indexes in differente file systems, indexes can be stored in a very fast but expensive file system while data can be stored in traditional file system and partition tables allow PostgreSQL engine to load few indexes to satisfy a query instead of load a unique large index improving query execution time.

## The repository

This repository contains scripts to modify zabbix 3.2 PostgreSQL scheme file, __create.sql.gz__,  in order to implement PostgreSQL __tablespaces__ and __inherited tables__ aka __partition tables__, the main target is to store items colected by Zabbix agents into several history tables, one table peer month, but keeping original zabbix querys's unmodified, This script will modify every __create table__ and __create index__ statement into __create.sql.gz__ file adding tablespace clauses to allow store data into diferent locations, data and indexes objects, remember that you should locate index data into very fast disk if it is possible to leverage database performance.

This script will create two aditional files, one file called __create_tablespaces.sql__ containing all statements to create tablespaces into zabbix database and other file called __create_functions.sql__ that contains statementes to define functions and triggers needed to re-direct inserts data clauses into history inherited tables.

### Related information

[PostgreSQL tablespaces](https://www.postgresql.org/docs/9.5/static/manage-ag-tablespaces.html)

[PostgreSQL inheritance](https://www.postgresql.org/docs/9.5/static/ddl-inherit.html)

[Zabbix server installation with PostgreSQL](https://www.zabbix.com/documentation/3.2/manual/installation/install_from_packages/server_installation_with_postgresql)

## Perl modules (dependencies)

[Cwd](http://perldoc.perl.org/Cwd.html)

[File::Copy](https://perldoc.perl.org/File/Copy.html)

[Getopt::Long](http://perldoc.perl.org/Getopt/Long.html)

[File::Basename](http://perldoc.perl.org/File/Basename.html)

[IO::Compress::Gzip](https://metacpan.org/pod/release/PMQS/IO-Compress-2.081/lib/IO/Compress/Gzip.pm)

[IO::Uncompress::Gunzip](https://metacpan.org/pod/release/PMQS/IO-Compress-2.081/lib/IO/Uncompress/Gunzip.pm)

[Date::Calc](https://metacpan.org/pod/Date::Calc)

## How to

### Preparing ZABBIX database

0. Install all Perl dependencies.

1. git clone https://github.com/jorgesanchez-e/zabbix-parttition-tables

2. Move file [zabbix32-transform.pl](https://github.com/jorgesanchez-e/1billion-with-zabbix/blob/master/zabbix32-transform.pl) into same directory than __create.sql.gz__ file is.

3. Execute [zabbix32-transform.pl](https://github.com/jorgesanchez-e/1billion-with-zabbix/blob/master/zabbix32-transform.pl) file with follow flags:

   ```shell
   --index=/path/to/index/directory/tablespace
   --data=/path/to/data/directory/tablespace
   ```

   Supousing you have _/opt/zabbix/data_ for data objects and _/opt/zabbix/index_ for index objects you have  execute following statement:

   ```shell
   ./zabbix32-transform.pl --data=/opt/zabbix/data --index=/opt/zabbix/data
   ```

   At the end it will create a new version file for __create.sql.gz__ and original file will be renamed to __create.sql.gz.old__ aditionally two new files will be created, __create_tablespaces.sql__ that will contains  statements to create tablespaces and __create_functions.sql__ file containing all functions and triggers needed to full fill inherited tables.

4. Create user database _zabbix_ as just as zabbix installation manual says:

   ```shell
   sudo -u postgres createuser --pwprompt zabbix
   ```

5. Create _zabbix database_ and assign it to _zabbix user_ as just as zabbix manual says:

   ``` shell
   sudo -u postgres createdb -O zabbix zabbix
   ```

6. Execute ___create_tablespace.sql__ file to create all needed tablespaces, you have to execute it with _postgresql_ user as just as shown below:

   ```shell
   cat ./create_tablespaces.sql | sudo -u postgres psql 
   ```

7. Execute __create.sql.gz__ file as just as zabbix manual says:

   ```shell
   zcat ./create.sql.gz | sudo -u zabbix psql zabbix 
   ```

8. Execute __create_functions.sql__ file as just as shown below:

   ```shell
   cat ./create_functions.sql | sudo -u zabbix psql
   ```

At this point you can follow instructions showed in [Zabbix server installation with PostgreSQL](https://www.zabbix.com/documentation/3.2/manual/installation/install_from_packages/server_installation_with_postgresql) to complete installation and at the end don't forget disable Zabbix house keeper process.



### Creating tables programmatically

Once you have up and running  your Zabbix server with PostgreSQL partitions you need a way to create  every month tables and it's index automatically to address this issue you can configure  __zabbix32-history-tables.pl__ script into a cronjob task putting line showed above into PostgreSQL user account.

```shell
0	0	25	*	*	/path/to/zabbix32-history-tables.pl --host <IP> --port <port>
```

This cronjob task will be execute every 25th day of every month and the script __zabbix32-history-tables.pl__ will create all tables and index needed for zabbix to store monitoring data for next inmediatly month.

Host and port arguments are optional, if PostgreSQL engine listens on default port over localhost you can ommit those arguments completly. 



### Installing with ansible

If you don't want to do all steeps I did a quite simple ansible playbook for this project and put it in [this link](https://github.com/jorgesanchez-e/ansible-zabbix-partition-tables).

