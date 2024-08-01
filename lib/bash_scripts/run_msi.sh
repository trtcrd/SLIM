#!/usr/bin/bash

# this script will run the msi pipeline


while getopts i:y:t:I:C:a:A:m:M:q:x:X:b:c: flag
do
    case "${flag}" in
	i) dir="$( cd -P "$( dirname "${OPTARG}" )" >/dev/null 2>&1 && pwd )/$( echo ${OPTARG%\/} | rev | cut -f1 -d '/' | rev )/";;
	y) input_file="${OPTARG}";;
    t) threads="${OPTARG}";;
	I) metadata="${OPTARG}";;
	C) cluster_min_reads="${OPTARG}";;
	a) cd_hit_cluster_threshold="${OPTARG}";;
	A) primer_max_error="${OPTARG}";;
	m) min_length="${OPTARG}";;
	M) max_length="${OPTARG}";;
    q) min_quality="${OPTARG}";;
    x) clust_mapped_threshold="${OPTARG}";;
    X) clust_aligned_threshold="${OPTARG}";;
    b) blast_database="${OPTARG}";;
    # c) config_file="${OPTARG}";;
	\?) echo "usage: bash run_msi.sh [-i|t|I|C|a|A|m|M|q|x|X|b]"; exit;;
    esac
done

if [ -z "${blast_database}" ]
 then
 echo "No database provided. Blast will not be run."
 SKIP_BLAST="Y"
else
 SKIP_BLAST="N"
 fi

# check if fastq_files has '$' in it
if [[ ${input_file} == *'€'* ]]; then
    echo "more than one fastq file"
    # change the $ to a space
    input_file=$(echo ${input_file} | sed 's/\€/\*/g')
fi

source /app/lib/msi/metabinkit_env.sh
export PATH=$PATH/root/.local/bin/
export PYTHONPATH=$PYTHONPATH:/app/lib/msi/python/lib/python3.9/site-packages/

cd $dir
# Define the path for the configuration file
config_file="${dir}params_file.cfg"

# Create the configuration file using a heredoc
cat <<EOF > "$config_file"
TL_DIR="${dir}input_msi"         # path to the toplevel folder containing the fastq files to be processed
OUT_FOLDER="${dir}"                 # path to the folder where the files produced by MSI will be stored
THREADS=${threads}                            # maximum number of threads
METADATAFILE="${metadata}"       # metadata about each fastq file
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


if [ $SKIP_BLAST == "N" ]
 then
 metabinkit_blastgendb -f ${blast_database} -o refdb/db -c -t ${threads}
 fi

mkdir -p input_msi
for file in $(ls ${input_file})
do
	gzip -c ${file} > input_msi/${file}.gz
	done

msi -c ${config_file} -i ${dir}input_msi

exit 0
