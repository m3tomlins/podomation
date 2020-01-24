#!/bin/bash
episodes="episodes"
clips="clips"
feedurl="https://{yoururl}.com/podcast/feed/podcast"

# GET THE LATEST FILES FROM RSS
cd ${episodes}
files=$(curl -sS ${feedurl} | grep enclosure | sed "s/https:\/\/dts.podtrac.com\/redirect.mp3\/dts.podtrac.com\/redirect.m4a\//http:\/\//g" | sed -e "s/.*\(http.*\.mp3\).*/\1/" -e "s/.*\(http.*\.m4a\).*/\1/")

# PARSE EACH FILENAME AND MAKE A FOLDER AND INFO FILE
for episode in ${files}; do
	echo "DEBUG: episode=${episode}"
	file=$(basename ${episode})
	name=$(basename ${episode} | cut -d"." -f1)
	type=$(basename ${episode} | cut -d"." -f2)
	infofile=${name}/${name}.info

	if [ ! -d ${name} ]; then
		# DOWNLOAD THE AUDIO FILE
		wget ${episode}

		# CREATE FOLDER AND MOVE ORIGINAL FILE THERE
		mkdir ${name}
		mv ${file} ${name}/.
		mkdir ${name}/backups
		cp ${name}/${name}.${type} ${name}/backups/.
			
		# WRITE THE ENTIRE INFO FILE
		duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ${name}/${file})
		bitrate=$(ffprobe -i ${name}/${file} -show_entries stream=bit_rate -v quiet | grep "bit_rate" | cut -d"=" -f2 | sed -e 's/0//g')
		size=$(stat -f%z ${name}/${file})
		echo "ORIG_FILE=${file}" > ${infofile}
		echo "ORIG_NAME=${name}" >> ${infofile}
		echo "ORIG_TYPE=${type}" >> ${infofile}
		echo "ORIG_DURATION=${duration}" >> ${infofile}
		echo "ORIG_SIZE=${size}" >> ${infofile}
		echo "ORIG_BITRATE=${bitrate}" >> ${infofile}
	else
		echo "DEBUG: this episode already exists locally..."
		local_file=$(cat ${infofile} | grep ORIG_FILE | cut -d"=" -f2)
		if [ "${file}" != "${local_file}" ]; then
			echo "CHECK: remote ${file} not same as ${local_file}"
		else
			echo "URL=${episode}" >> ${infofile}
		fi
	fi	


done
