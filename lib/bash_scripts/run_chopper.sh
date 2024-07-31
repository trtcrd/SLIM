#!/usr/bin/bash

# this script will run the chopper


while getopts i:q:h:t:m:M:c:o: flag
do
    case "${flag}" in
	i) input="${OPTARG}";;
    q) quality="${OPTARG}";;
	h) headcrop="${OPTARG}";;
	t) tailcrop="${OPTARG}";;
	m) minlength="${OPTARG}";;
	M) maxlength="${OPTARG}";;
	c) threads="${OPTARG}";;
	o) output="${OPTARG}";;
	\?) echo "usage: bash run_chopper.sh [-i|q|h|t|m|M|c|o]"; exit;;
    esac
done

echo 'chopper started'

source activate chopper

echo 'virtual environment activated'

/root/miniconda3/envs/chopper/bin/chopper --input ${input} --quality ${quality} --headcrop ${headcrop} --tailcrop ${tailcrop} --minlength ${minlength} --maxlength ${maxlength} --threads ${threads} > ${output}

echo 'chopper finished'
exit 0
