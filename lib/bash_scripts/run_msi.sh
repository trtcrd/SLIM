#!/usr/bin/bash

# this script will run the msi pipeline but only for one primer set at a time
# there will be a first step in which cutadapt will be run to detect the reverse
# sequences and to revert them to the correct orientation


# I decide to create the metadata from the inputs of the user. 

# Only one primer every time can be used in this script.

# for every sample, first it will take the fastq file and divide it in two for the 
# correct orientated sequences and the reverse complementaries with cutadapt.

# this is the example:
# cutadapt -g AGATCGGAAGAGC -o output_with_pattern.fastq --untrimmed-output output_without_pattern.fastq input.fastq

# then with seqtk it will take the reverse complementaries and revert them to the correct orientation
# seqtk seq -r in.fq > out.fq

# finally concatenate the two files and run the msi pipeline

# the metadata needs the following columns:
# sample_id: unique identifier of the sample
# ss_sample_id
# primer_set: unique identifier of the primer
# primer_f: 5'end primer sequence (forward primer)
# primer_r: 3'end reverse complemented primer sequence (reverse primer)
# min_length: minimum length of the fragment
# max_length: maximum length of the fragment
# target_gene: name of the gene targeted
# barcode_name: unique identifier for the file (e.g., library name)

# centroids samples should then be used on optics to get the otu_table


# while getopts i:y:t:I:C:a:A:m:M:q:x:X:b:c: flag
while getopts i:y:t:o:p:C:a:A:m:M:q:x:X:b:c: flag
do
    case "${flag}" in
	i) dir="$( cd -P "$( dirname "${OPTARG}" )" >/dev/null 2>&1 && pwd )/$( echo ${OPTARG%\/} | rev | cut -f1 -d '/' | rev )/";;
	y) input_file="${OPTARG}";;
    t) threads="${OPTARG}";;
    o) output_file="${OPTARG}";;
	# I) metadata="${OPTARG}";;
    p) primers="${OPTARG}";;
    # g) target_gene="${OPTARG}";;
	C) cluster_min_reads="${OPTARG}";;
	a) cd_hit_cluster_threshold="${OPTARG}";;
	A) primer_max_error="${OPTARG}";;
	m) min_length="${OPTARG}";;
	M) max_length="${OPTARG}";;
    q) min_quality="${OPTARG}";;
    x) clust_mapped_threshold="${OPTARG}";;
    X) clust_aligned_threshold="${OPTARG}";;
    # b) blast_database="${OPTARG}";;
    # c) config_file="${OPTARG}";;
	\?) echo "usage: bash run_msi.sh [-i|t|o|p|C|a|A|m|M|q|x|X|b]"; exit;;
    esac
done

# if [ -z "${blast_database}" ]
#  then
#  echo "No database provided. Blast will not be run."
#  SKIP_BLAST="Y"
# else
#  SKIP_BLAST="N"
#  fi
SKIP_BLAST="Y"

# check if fastq_files has '$' in it
if [[ ${input_file} == *'€'* ]]; then
    echo "more than one fastq file"
    # change the $ to a space
    input_file=$(echo ${input_file} | sed 's/\€/\*/g')
fi
# check if fastq_files has '$' in it
if [[ ${output_file} == *'€'* ]]; then
    echo "more than one fastq file"
    # change the $ to a space
    output_file=$(echo ${output_file} | sed 's/\€/\*/g')
fi

source activate msi
source /app/lib/msi/metabinkit_env.sh
export PATH=$PATH:/root/.local/bin/
export PYTHONPATH=$PYTHONPATH:/app/lib/msi/python/lib/python3.9/site-packages/

cd $dir
# Define the path for the configuration file
config_file="${dir}params_file.cfg"

# Create the configuration file using a heredoc
cat <<EOF > "$config_file"
TL_DIR="${dir}input_msi"         # path to the toplevel folder containing the fastq files to be processed
OUT_FOLDER="${dir}"                 # path to the folder where the files produced by MSI will be stored
THREADS=${threads}                            # maximum number of threads
METADATAFILE="metadata.tsv"       # metadata about each fastq file
SKIP_BLAST="${SKIP_BLAST}"                       # Stop MSI before blast? Yes/No
TAXONOMY_DATA_DIR="/app/lib/msi/db"      # path to the taxonomy database 
CLUSTER_MIN_READS=${cluster_min_reads}                  # minimum number of reads per cluster
CD_HIT_CLUSTER_THRESHOLD=${cd_hit_cluster_threshold}        # cluster/group reads with a similitiry greater than the given threshould (range from 0 to 1)
PRIMER_MAX_ERROR=${primer_max_error}                 # maximum error accepted when matching a primer sequence to the reads

MIN_LEN=${min_length}                           # Reads shorter than MIN_LEN are discarded
MAX_LEN=${max_length}                      # Reads longer than MAX_LEN are discard
MIN_QUAL=${min_quality}                           # Minimum phred score

EXPERIMENT_ID=.                      # can be used to filter the entries in the metadata file 
## Parameters from isONclust
# Minmum mapped fraction of read to be included in cluster. 
CLUST_MAPPED_THRESHOLD=${clust_mapped_threshold}
# Minmum aligned fraction of read to be included in cluster. Aligned
# identity depends on the quality of the read. (default: 0.4)
CLUST_ALIGNED_THRESHOLD=${clust_aligned_threshold}


### binning options (passed to metabinkit, check metabinkit manual for details)
#mbk_Species=
#mbk_Genus=
#mbk_Family=
#mabk_AboveF=
#mbk_TopSpecies=
#mbk_TopGenus=
#mbk_TopFamily=
#mbk_TopAF=
#mbk_sp_discard_sp=              
#mbk_sp_discard_mt2w=
#mbk_sp_discard_num=
#mbk_minimal_cols=
#mbk_no_mbk=
#mbk_FilterFile=
#mbk_FilterCol=
#mbk_FamilyBL=
#mbk_GenusBL=
#mbk_SpeciesBL=
#mbk_SpeciesNegFilter=

### blast options (passed to blast, check blast manual for details)
blast_refdb="refdb/db"            # path to a blast database
#blast_max_hsps= 
#blast_word_size=
#blast_perc_identity=
#blast_qcov_hsp_perc= 
#blast_gapopen= 
#blast_gapextend=
#blast_reward=
#blast_evalue=
#blast_penalty=
#blast_max_target_seqs=
#blast_taxids_blacklist_files=
#blast_taxids_poslist_files= 
EOF


# if [ $SKIP_BLAST == "N" ]
#  then
#  metabinkit_blastgendb -f ${blast_database} -o refdb/db -c -t ${threads}
#  fi
# primers_rc=${primers/.fasta/_rc.fasta}
# get complementaries
# /app/lib/msi/seqtk/seqtk seq -r ${primers} > ${primers_rc}

primer_f=$(sed -n '2p' ${primers})
primer_r=$(sed -n '4p' ${primers})

# check for '-' and remove them from primers
if [[ ${primer_f} == *'-'* ]]; then
    primer_f=$(echo ${primer_f} | sed 's/-//g')
fi
if [[ ${primer_r} == *'-'* ]]; then
    primer_r=$(echo ${primer_r} | sed 's/-//g')
fi

# create metadata file
echo -e "sample_id\tss_sample_id\tprimer_set\tprimer_f\tprimer_r\tmin_length\tmax_length\ttarget_gene\tbarcode_name" > metadata.tsv
i=1
dir2=${dir}/redirected_fastq/
mkdir -p ${dir2}
for file in $(ls ${input_file})
do
    # sample_id=$(basename ${file} | cut -f1 -d '.')
    sample_id=${file/.fastq/}
    echo -e "${sample_id}\tsample_${i}\t${primers}\t${primer_f}\t${primer_r}\t${min_length}\t${max_length}\t${primers}\t${sample_id}" >> metadata.tsv
    i=$((i+1))

    # cutadapt -g ${primer_f} -o ${dir2}${sample_id}_with_pattern.fastq --untrimmed-output ${dir2}${sample_id}_without_pattern.fastq ${file}
    # cutadapt -g ${primer_f} --action=none -o ${dir2}${sample_id}_correct_dir.fastq --discard-untrimmed ${file}
    # cutadapt -g ${primer_r} --action=none -o ${dir2}${sample_id}_incorrect_dir.fastq --discard-untrimmed ${file}
    # cutadapt -g ${primer_f} --action=none -o ${dir2}${sample_id}_correct_dir.fastq --untrimmed-output ${dir2}${sample_id}_first_discard.fastq ${file}
    # cutadapt -g ${primer_r} --action=none -o ${dir2}${sample_id}_incorrect_dir.fastq --discard-untrimmed ${dir2}${sample_id}_first_discard.fastq

    # /app/lib/msi/seqtk/seqtk seq -r ${dir2}${sample_id}_incorrect_dir.fastq > ${dir2}${sample_id}_incorrect_dir_rc.fastq
    # cat ${dir2}${sample_id}_correct_dir.fastq ${dir2}${sample_id}_incorrect_dir_rc.fastq > ${dir2}${sample_id}.fastq
    cp ${file} ${dir2}${sample_id}.fastq
done


mkdir -p input_msi
for file in $(ls ${input_file})
do
    mkdir -p input_msi/${file/.fastq/}
    # check if there is \t between the heather sections
    sed -i "s/\t/ /g" redirected_fastq/${file}
	gzip -c redirected_fastq/${file} > input_msi/$(basename ${file} | cut -f1 -d '.')/${file}.gz
	done

msi -c ${config_file} -i ${dir}input_msi

# once finished a tar.gz file named sample_centroids = 'sample_centroids.tar.gz' must be created
# to be able to download it

# also in order to run optics the centroids must be renamed for eac sample to *.consensus.fasta
# also check that the format is correct for the optics script

empty_files=''
there_are_empty_files='N'
for file in $(ls ${input_file})
do
    sample_id=${file/.fastq/}
    cp ${dir}${sample_id}/${sample_id}.centroids.fasta ${dir}${sample_id}_consensus.fasta
    sed -i 's/:\([^=]*=\)/;\1/g' ${dir}${sample_id}_consensus.fasta
    
    # Check if the file is empty and print a message if it is
    # if empty don't remove the folder to debug manually
    if [ ! -s ${dir}${sample_id}_consensus.fasta ]; then
        empty_files="${empty_files} ${sample_id}"
        there_are_empty_files='Y'
    else
        rm -r ${dir}${sample_id}
    fi
done

# # check if output_file has "_consensus.fasta" in it
# if [[ ${output_file} == *'_consensus.fasta'* ]]; then
#     echo "output_file has _consensus.fasta in it"
#     # change the $ to a space
#     output_file=$(echo ${output_file} | sed 's/_consensus.fasta//g')
# fi

# tar --use-compress-program=pigz -Pcf "${output_file}" -C ${dir} ./*_consensus.fasta

# check if there are empty files
# if empty don't remove the folder to debug manually
if [ $there_are_empty_files == 'Y' ]; then
    echo "The following files are empty: ${empty_files}"
    exit 1 # There are empty files
else
    rm -r ${dir2}
    exit 0
fi