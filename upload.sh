#!/bin/bash
base=$PWD
episodes=${base}/episodes
episode="$1"
info_file=${episodes}/${episode}/${episode}.info
type=$(cat ${info_file} | grep ORIG_TYPE | cut -d"=" -f2)
ftp_host=$(cat upload.credentials | grep ftp_host | cut -d"=" -f2)
ftp_user=$(cat upload.credentials | grep ftp_user | cut -d"=" -f2)
ftp_password=$(cat upload.credentials | grep ftp_password | cut -d"=" -f2)
echo "UPLOADING: ${episode} to ${ftp_host}"
cd ${episodes}/${episode}
ftp -v -n $ftp_host<<-FTPSCRIPT
quote USER $ftp_user
quote PASS $ftp_password
binary
passive
put ${episode}.${type}
quit
FTPSCRIPT
cd ${base}
