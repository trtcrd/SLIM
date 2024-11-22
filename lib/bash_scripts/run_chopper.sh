#!/usr/bin/bash

# this script will run the chopper


while getopts i:q:h:t:m:M:c:o: flag
do
    case "${flag}" in
	i) input_file="${OPTARG}";;
    q) quality="${OPTARG}";;
	h) headcrop="${OPTARG}";;
	t) tailcrop="${OPTARG}";;
	m) minlength="${OPTARG}";;
	M) maxlength="${OPTARG}";;
	c) threads="${OPTARG}";;
	o) output_file="${OPTARG}";;
	\?) echo "usage: bash run_chopper.sh [-i|q|h|t|m|M|c|o]"; exit;;
    esac
done

echo 'chopper started' > output_messages_chopper.txt

source activate chopper

echo 'virtual environment activated' >> output_messages_chopper.txt

# check if fastq_files has '$' in it
if [[ ${input_file} == *'€'* ]]; then
    echo "more than one fastq file" >> output_messages_chopper.txt
    # change the $ to a space
    output_file=$(echo ${output_file} | sed 's/\*/\€/g')
    output_sufix=${output_file/${input_file/.fastq/}/}
    input_file=$(echo ${input_file} | sed 's/\€/\*/g')
else
    output_sufix=${output_file/${input_file/.fastq/}/}
fi

there_are_empty_files='N'
empty_files=''

for file in $(ls ${input_file})
do
	sample_id=${file/.fastq/}
	output=${sample_id}${output_sufix}
	echo running chopper  >> output_messages_chopper.txt
	echo "chopper --input ${file} --quality ${quality} --headcrop ${headcrop} --tailcrop ${tailcrop} --minlength ${minlength} --maxlength ${maxlength} --threads ${threads} > ${output}" >> output_messages_chopper.txt
	/root/miniforge3/envs/chopper/bin/chopper --input ${file} --quality ${quality} --headcrop ${headcrop} --tailcrop ${tailcrop} --minlength ${minlength} --maxlength ${maxlength} --threads ${threads} > ${output}

	if [ ! -s ${output} ]; then
        empty_files="${empty_files} ${output}"
        there_are_empty_files='Y'
    fi
done

if [ $there_are_empty_files == 'Y' ]; then
    echo "The following files are empty: ${empty_files}" >> output_messages_chopper.txt
    exit 1 # There are empty files
else
    echo 'chopper finished' >> output_messages_chopper.txt
	exit 0
fi
