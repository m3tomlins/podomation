#!/bin/bash

base=$PWD
episodes="${base}/episodes"
transcribble_url="http://jmglov.net/software/transcribble/transcribble.jar"

warn() {
  echo "$1" 1>&2
}

usage() {
  exit_code=$1
  if [ $exit_code -eq 0 ]; then
    output=echo
  else
    output=warn
  fi

  $output "Usage: $(basename $0) COMMAND EPISODE_NAME [OPTION]"
  $output
  $output "  where COMMAND is one of:"
  $output
  $output "    start-job [--speakers NAMES]           starts a job"
  $output "    check-status                           checks the status of a job"
  $output "    download-transcript                    downloads transcript for a completed job"
  $output "    convert-transcript --speakers NAMES    converts a downloaded transcript to OTR format;"
  $output "                                           requires --speaker NAMES (see below)"
  $output "    install                                install transcribble jar"
  $output
  $output "  and valid OPTIONs are:"
  $output "    --speakers NAMES                       comma-separated list of speaker names; e.g."
  $output "                                           'Kim Kay,Ashley Ames' or 'Kim Kay'"

  exit $exit_code
}

if [[ -z "$AWS_PROFILE" && -z "$AWS_ACCESS_KEY_ID" ]]; then
  warn "Please set AWS_PROFILE or AWS_ACCESS_KEY_ID (and AWS_SECRET_ACCESS_KEY) env variables"
  exit 254
fi

if [ -z "$S3_BUCKET" ]; then
  warn "Please set S3_BUCKET env var to the S3 bucket used for transcription jobs"
  exit 254
fi

if [ -z "$S3_MEDIA_PATH" ]; then
  warn "Please set S3_MEDIA_PATH env var to the path in S3_BUCKET to use for media files"
  exit 254
fi

command="$1"; shift
if [ -z "$command" ]; then
  warn "Missing required argument: COMMAND"
  warn

  usage 254
fi

episode_name="$1"; shift
if [ -z "$episode_name" ]; then
  warn "Missing required argument: EPISODE_NAME"
  exit 254
fi

media_file=$(echo $episode_name.mp3 | sed -e 's/[.]mp3[.]mp3$/.mp3/')

case $command in
  start-job)
    if [ "$1" == '--speakers' ]; then
      num_speakers=$(echo "$speakers" | awk -F "," '{print NF-1}')
      shift; shift

      settings="--settings ShowSpeakerLabels=true,MaxSpeakerLabels=${num_speakers}"
    fi

    aws s3 ls s3://${S3_BUCKET}/${S3_MEDIA_PATH}/$media_file \
      || aws s3 cp $episodes/$episode_name/$media_file s3://${S3_BUCKET}/${S3_MEDIA_PATH}/$media_file \
      || exit $?

    aws transcribe start-transcription-job \
      --transcription-job-name $episode_name \
      --language-code en-US \
      --media-sample-rate-hertz 48000 \
      --media-format mp3 \
      --media MediaFileUri=s3://$S3_BUCKET/$S3_MEDIA_PATH/$media_file \
      --output-bucket-name $S3_BUCKET \
      $settings
    exit $?
    ;;

  check-status)
    aws transcribe get-transcription-job \
        --transcription-job-name $episode_name
    exit $?
    ;;

  download-transcript)
    aws s3 cp s3://$S3_BUCKET/$episode_name.json $episodes/$episode_name/
    exit $?
    ;;

  convert-transcript)
    if [ -z "$TRANSCRIBBLE_JAR" ]; then
      warn "Please set TRANSCRIBBLE_JAR env var to the location of the Transcribble JAR file"
      exit 254
    fi

    if [ "$1" == '--speakers' ]; then
      speakers="$1"
      shift
    else
      warn "Missing required option --speakers NAME"
      warn
      usage 254
    fi

    if [ -e "config.json" ]; then
      config_file="config.json"
    else
      config_file=""
    fi

    java -jar $TRANSCRIBBLE_JAR ${episodes}/${episode_name}/${episode_name}.json \
      ${episodes}/${episode_name}/${episode_name}.otr \
      ${episodes}/${episode_name}/${episode_name}.mp3 \
      "$speakers" $config_file
    exit $?
    ;;

  install)
    if [ -z "$TRANSCRIBBLE_JAR" ]; then
      warn "Please set TRANSCRIBBLE_JAR env var to the location of the Transcribble JAR file"
      exit 254
    fi

    curl "${transcribble_url}" >"${TRANSCRIBBLE_JAR}"
    exit $?
    ;;

  *)
    warn "Invalid command: $command"
    warn
    usage 254
    ;;
esac
