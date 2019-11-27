#!/bin/bash

# USAGE AND ARGS
display_usage() { 
  echo -e "Usage:\tpodomate.sh [episode folder] [upload:true/false]" 
  echo -e "\tepisode folder = the name of the folder under episodes"
  echo -e "\tupload = should the output audio file be uploaded to Blubrry"
} 
# if less than two arguments supplied, display usage 
  if [  $# -le 1 ];then
    display_usage
  fi 
 
# check whether user had supplied -h or --help . If yes display usage 
  if [[ ( $# == "--help") ||  $# == "-h" ]];then
    display_usage
  fi 
 
## MAIN ENVIRONMENT
base=$PWD
episode=${1}
upload=${2:-"false"}
clips="${base}/clips"
episodes="${base}/episodes"
backups="${episodes}/${episode}/backups"
info_file=${episodes}/${episode}/${episode}.info

## IF THE EPISODE FOLDER DOESN'T EXIST, ABORT
if [ ! -d ${episodes}/${episode} ]; then
	echo "ERROR: ${episodes}/${episode} does not exist!!"
	exit -1;
fi
if [ ! -f ${info_file} ]; then
	echo "ERROR: ${info_file} does not exist!!"
	exit -1;
fi

## IF THERE IS NO .MP3 or .M4A THIS IS A NEW EPISODE
if [[ ! -f ${episodes}/${episode}/${episode}.m4a && ! -f ${episodes}/${episode}/${episode}.mp3 ]]; then
	new_episode="true"
	file=${episode}.mp3
	name=${episode}
	type="mp3"
	bitrate="128"
else
	new_episode="false"
	file=$(cat ${info_file} | grep ORIG_FILE | cut -d"=" -f2)
	name=$(cat ${info_file} | grep ORIG_NAME | cut -d"=" -f2)
	type=$(cat ${info_file} | grep ORIG_TYPE | cut -d"=" -f2)
	size=$(cat ${info_file} | grep ORIG_SIZE | cut -d"=" -f2)
	duration=$(cat ${info_file} | grep ORIG_DURATION | cut -d"=" -f2)
	bitrate=$(cat ${info_file} | grep ORIG_BITRATE | cut -d"=" -f2)
fi

## PARSE THE CLIP INFO AND CREATE A SOX SCRIPT
sox_script="/tmp/${episode}.sh"
echo -e "#!/bin/bash\nsox --combine mix --show-progress \\" > ${sox_script}
elapsed="0"
for clip in $(cat ${info_file} | grep CLIP); do
	clip_num=$(echo ${clip} | cut -d"_" -f2 | cut -d"=" -f1)
	clip_file=$(echo ${clip} | cut -d"=" -f2 | cut -d"," -f1)
	clip_pad=$(echo ${clip} | cut -d"," -f2 | cut -d"=" -f2)
	if [ -f ${clip_file} ]; then
		clip_duration=$(soxi -D ${clip_file})
		padding=$(echo ${elapsed} - ${clip_pad} | bc)
	 	echo -e "${sox_cmd}\"|sox ${clip_file} -p pad ${padding} 0\" \\" >> ${sox_script}
		echo "ADDED: ${clip_file} at ${padding} seconds"
		elapsed=$(echo ${elapsed} + ${clip_duration} - ${clip_pad} | bc)
	else
		echo "ERROR: ${clip_file} is not found!!"
		exit -1;
	fi
done

## MIX IT ALL DOWN WITH -6db Normalization
remix_wav="/tmp/remix_${RANDOM}.wav"
echo -e "${remix_wav} gain -n -6" >> ${sox_script}
echo "MIXING DOWN to ${remix_wav}...."
$(. ${sox_script})

echo "CREATED THE REMIX WAVE"
ls -al ${remix_wav}

## BACKUP ANY EXISTING MIXDOWN
if [ ! -d ${backups} ]; then
	echo "CREATED BACKUP DIRECTORY"
	mkdir ${backups}
fi

if [ -f ${episodes}/${episode}/${episode}.${type} ]; then
	echo "BACKING UP ${episode}.${type}"
	mv ${episodes}/${episode}/${episode}.${type} ${episodes}/${episode}/${episode}.${type}.tmp
fi

## CONVERT THE NEW MIXDOWN TO TARGET FORMAT
echo "CONVERTING TO ${episode}.${type}..."
case ${type} in
	mp3)
		# Converting from WAV to MP3
		newmix=${episodes}/${episode}/${episode}.mp3
		sox -S ${remix_wav} -c 2 -C ${bitrate}.01 -t mp3 ${newmix}
		size=$(stat -f%z ${newmix})
		duration=$(soxi -D ${newmix})
		bitrate=$(soxi -B ${newmix} | sed -e 's/k//g')
	;;
	m4a)
		# Converting from WAV to M4A
		newmix=${episodes}/${episode}/${episode}.m4a
		ffmpeg -i ${remix_wav} -ar 44100 ${newmix}
		size=$(stat -f%z  ${newmix})
		duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ${newmix})
		bitrate=$(( $(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 ${newmix}) / 1000))
	;;
	*)
		echo "ERROR: TYPE $type IS NOT SUPPORTED!"
	;;
esac

## make backup copy of the newmix 
cp ${episodes}/${episode}/${episode}.${type} ${backups}/${episode}.${type}.$(date '+%Y%m%d%H%M%S')

if [ $new_episode = true ]; then
	echo "WRITING INFO ${info_file}..."
	echo -e "\nORIG_FILE=${episode}.${type}" >> ${info_file}
	echo "ORIG_NAME=${episode}" >> ${info_file}
	echo "ORIG_TYPE=${type}" >> ${info_file}
	echo "ORIG_SIZE=${size}" >> ${info_file}
	echo "ORIG_DURATION=${duration}" >> ${info_file}
	echo "ORIG_BITRATE=${bitrate}" >> ${info_file}

else
	cat ${info_file} | grep -v "NEW_" > ${info_file}.new
	echo "NEW_SIZE=${size}" >> ${info_file}.new
	echo "NEW_DURATION=${duration}" >> ${info_file}.new
	echo "NEW_BITRATE=${bitrate}" >> ${info_file}.new
	mv ${info_file}.new ${info_file}

	## TEST FOR MIXDOWN DURATION COMPARED TO ORIG DURATION/SIZE
	#duration_diff=$(echo "${duration}-${new_duration}" | bc)
	#echo "NEW_DURATION: ${duration_diff}"

	#size_diff=$(echo "${size}-${new_size}" | bc)
	#percent_diff=$(echo "scale=4; (${size} - ${new_size}) / ${new_size} * 100" | bc -l)
	#percent_diff=${percent_diff#-}
	#echo "NEW_SIZE: ${size_diff} / ${percent_diff} %"
fi
cat ${info_file}


if [ "${upload}" == "true" ]; then
	ftp_host=$(cat upload.credentials | grep ftp_host | cut -d"=" -f2)
	ftp_user=$(cat upload.credentials | grep ftp_user | cut -d"=" -f2)
	ftp_password=$(cat upload.credentials | grep ftp_password | cut -d"=" -f2)
	echo "UPLOADING: ${newmix} to ${ftp_host}"
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
fi	

## COPY TO THE GOOGLE DRIVE FOLDER READY FOR KIM
#cp ${newmix} /Volumes/NEXSTAR/CauseAScene/Google\ Drive/Ready\ for\ Kim/.

## remove temp files
rm ${remix_wav}
if [ -f ${episodes}/${episode}/${episode}.${type}.tmp ]; then
   rm -f ${episodes}/${episode}/${episode}.${type}.tmp
fi
