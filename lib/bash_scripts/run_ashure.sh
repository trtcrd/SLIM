#!/usr/bin/bash

# this script will run the ashure pipeline


while getopts f:p:m:M:d:s:t:T:N:i:C:c:o: flag
do
    case "${flag}" in
	f) fastq_files="${OPTARG}";;
	p) primers="${OPTARG}";;
	d) directory="$( cd -P "$( dirname "${OPTARG}" )" >/dev/null 2>&1 && pwd )/$( echo ${OPTARG%\/} | rev | cut -f1 -d '/' | rev )/";;
	m) min_length="${OPTARG}";;
	M) max_length="${OPTARG}";;
  s) clst_csize="${OPTARG}";;
  t) clst_th_m="${OPTARG}";;
  T) clst_th_s="${OPTARG}";;
  N) clst_N="${OPTARG}";;
  i) clst_N_iter="${OPTARG}";;
  C) cons_file="${OPTARG}";;
  c) cin_file="${OPTARG}";;
  o) cout_file="${OPTARG}";;
	\?) echo "usage: bash run_ashure.sh [-f|p|m|M|d|s|t|T|N|i|C|c|o]"; exit;;
    esac
done

# check if fastq_files has '$' in it
if [[ ${fastq_files} == *'€'* ]]; then
    echo "more than one fastq file"
    # change the $ to a space
    fastq_files=$(echo ${fastq_files} | sed 's/\€/\*/g')
fi


# export paths
export PATH=$PATH:/root/.local/bin/:
# export paths to minimap2 and spoa
export PATH=$PATH/app/lib/msi/bin/:/app/lib/ASHURE/spoa/build/bin/

# export paths to ashure
export PATH=$PATH/app/lib/ASHURE/src/:

source activate ashure

cd ${directory}

config_file="config.json"

# Create the configuration file using a heredoc
cat <<EOF > "$config_file"
{
  "spoa_path": "/app/lib/ASHURE/spoa/build/bin/spoa",
  "minimap2_path": "/app/lib/msi/bin/minimap2",
  "low_mem": false,
  "fastq": [],
  "exclude": [],
  "primer_file": "${primers}",
  "db_file": "pseudodb.csv",
  "workspace": "./workspace/",
  "cons_file": "${cons_file}",
  "pmatch_file": "pmatch.csv.gz",
  "cin_file": "${cin_file}",
  "cout_file": "${cout_file}",
  "log_file": "ashure.log",
  "config_file": "${config_file}",
  "prfg_fs": "${min_length}-${max_length}",
  "prfg_config": "-k5 -w1 -s 20 -P",
  "prfg_pmr_thresh": 10,
  "fgs_config": "-k10 -w1",
  "frag_folder": "./frags/",
  "msa_config": "-n -15 -g -10 -l 0 -r 0",
  "msa_folder": "./msa/",
  "msa_metric": "AS",
  "msa_thresh": 50,
  "msa_batch_size": 100,
  "msa_thread_lock": false,
  "msa_gap_thresh": 4,
  "msa_padding": 0,
  "fpmr_config": "-k5 -w1 -s 20 -P",
  "fpmr_thresh": 10,
  "clst_init": "",
  "clst_folder": "./clusters/",
  "clst_min_k": 5,
  "clst_csize": ${clst_csize},
  "clst_th_m": ${clst_th_m},
  "clst_th_s": ${clst_th_s},
  "clst_N": ${clst_N},
  "clst_N_iter": ${clst_N_iter},
  "clst_iter_out": "clst",
  "clst_track": false,
  "clst_pw_config": "-k15 -w10 -p 0.9 -D",
  "subcommand": "run"
}
EOF

mkdir -p fastq_dir
cp ${fastq_files} fastq_dir/.
python3 /app/lib/ASHURE/src/ashure.py run -fq fastq_dir/* -c ${config_file} 
# S1.1 Pseudo reference database generation
# The following alignment parameters are used in minimap2 to find primer sequences:
# minimap2 -k5 -w1 -s 20 -P primers.fa reads.fa > output.paf
## is the previous line within ashure?
# The following commands are passed on to ASHURE to build the pseudo reference database:
# ashure.py prfg -fq fastq/*.fq -p primers.csv -fs 500-1200 -o database.csv -r
# python3 /app/lib/ASHURE/src/ashure.py prfg -fq ${fastq_dir}/* -p ${primers} -fs ${min_length}-${max_length} -o database.csv -r

# S1.2 Concatemer identification
# Concatemers are identified by mapping each raw read against the pseudo reference database with
# minimap2. Putative concatemers sites are sorted by the alignment score. Only the highest-scoring nonoverlapping alignments in each raw read are kept for downstream analysis.
# The following parameters are used in minimap2 to find concatemers:
# minimap2 -k10 -w1 database.fa reads.fa > output.paf
## is the previous line within ashure?
# The following commands are passed on to ASHURE to find concatemer sites:
# ashure.py fgs -fq fastq/*.fq -db database.csv -o concatemers/ -r
# python3 /app/lib/ASHURE/src/ashure.py fgs -fq ${fastq_dir}/* -db database.csv -o concatemers/ -r

# S1.3 Consensus error correction
# For raw reads with more than one concatemer, concatemers are extracted, reoriented 5'->3', and multialigned with spoa (Vaser et al. 2017) to generate an error-corrected consensus sequence for each read.
# The following parameters are used in spoa:
# spoa -n -15 -g -10 -l 0 -r 0 concatemers.fq > output.txt
## is the previous line within ashure?
# The following commands were passed on to ASHURE to perform multi-alignment and consensus:
# python3 /app/lib/ASHURE/src/ashure.py msa -i concatemers/ -o1 msa/ -o2 corrected_reads.csv -r1 -r2

# S1.4 Primer identification
# Error corrected reads are mapped to forward and reverse primer sequences with minimap2. Primer
# pairs are assigned based on the highest combined alignment score.
# The following parameters are used in minimap2 to find primer sequences:
# minimap2 -k5 -w1 -s 20 -P primers.fa reads.fa > output.paf
## is the previous line within ashure?
# The following commands are passed to ASHURE to perform primer assignment and trimming of
# corrected reads:
# python3 /app/lib/ASHURE/src/ashure.py fpmr -i corrected_reads.csv -p primers.csv -o1 primer_match.csv -o2 trimmed_reads.csv -r1 -r2

# The following commands are passed on to ASHURE to perform concatemer search, multi-alignment,
# consensus generation, primer identification, and read trimming:
# python3 /app/lib/ASHURE/src/ashure.py run -fq fastq/*.fq -db database.csv -o1 creads.csv -r fgs,msa,cons,fpmr, trmc