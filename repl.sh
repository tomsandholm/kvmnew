#! /bin/bash 

sed -i '/\[mysqld\]/a\
log-bin\
server_id=<NUM>\
log-basename=<HOST><NUM>' ./my.cnf

