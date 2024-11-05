#!/usr/bin/bash

# this script will run the optics algorithm from ashure


while getopts f:d:s:t:T:N:i:S:c:o: flag
do
    case "${flag}" in
	f) fasta_files="${OPTARG}";;
	d) directory="$( cd -P "$( dirname "${OPTARG}" )" >/dev/null 2>&1 && pwd )/$( echo ${OPTARG%\/} | rev | cut -f1 -d '/' | rev )/";;
	s) clst_csize="${OPTARG}";;
    t) clst_th_m="${OPTARG}";;
    T) clst_th_s="${OPTARG}";;
    N) clst_N="${OPTARG}";;
    i) clst_N_iter="${OPTARG}";;
    S) sim_thr="${OPTARG}";;
    c) fasta_out="${OPTARG}";;
    o) otutab="${OPTARG}";;
	\?) echo "usage: bash run_optics.sh [-f|d|s|t|T|N|i|S|c|o]"; exit;;
    esac
done

# check if fastq_files has '$' in it
if [[ ${fasta_files} == *'€'* ]]; then
    echo "more than one fastq file"
    # change the $ to a space
    fasta_files=$(echo ${fasta_files} | sed 's/\€/\*/g')
fi


# export paths
export PATH=$PATH:/root/.local/bin/:
# export paths to minimap2 and spoa
export PATH=$PATH:/app/lib/msi/bin/:/app/lib/ASHURE/spoa/build/bin/:

# export paths to ashure
export PATH=$PATH/app/lib/ASHURE/src/:


source activate ashure

cd ${directory}

mkdir -p ft_dir_tmp
cp ${fasta_files} ft_dir_tmp/.

mkdir -p concat_dir_tmp
# if [[ ${fasta_files} == *'.f'*'q'* ]]; then
#     cat ft_dir_tmp/* >concat_dir_tmp/concatenated.fastq
#     concatenated=${directory}/concat_dir_tmp/concatenated.fastq
# else
cat ft_dir_tmp/* >concat_dir_tmp/concatenated.fasta
concatenated=${directory}/concat_dir_tmp/concatenated.fasta
# fi

config_file="config.json"

# Create the configuration file using a heredoc
cat <<EOF > "$config_file"
{
  "spoa_path": "/app/lib/ASHURE/spoa/build/bin/spoa",
  "minimap2_path": "/app/lib/msi/bin/minimap2",
  "low_mem": false,
  "fastq": [],
  "exclude": [],
  "primer_file": "",
  "db_file": "",
  "workspace": "${directory}/workspace/",
  "cons_file": "",
  "pmatch_file": "pmatch.csv.gz",
  "cin_file": "${concatenated}",
  "cout_file": "${directory}/centers.csv",
  "log_file": "ashure.log",
  "config_file": "${directory}/${config_file}",
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
  "subcommand": "clst"
}
EOF

# python3 /app/lib/ASHURE/src/ashure.py clst -i ${concatenated} -o centers.csv -N ${clst_N} -cs ${clst_csize} -tm ${clst_th_m} -ts ${clst_th_s} -iter ${clst_N_iter} -r

python3 /app/lib/ASHURE/src/ashure.py run -c ${config_file} -r clst

mkdir -p fasta_dir_tmp


# if [[ ${fasta_files} == *.f*q* ]]; then
#     for file in ft_dir_tmp/*; do
#         /app/lib/vsearch/bin/vsearch --fastq_filter ${directory}/${file} --fastaout ${directory}/fasta_dir_tmp/$(basename ${file} | cut -f1 -d '.').fasta --threads 8 --fastq_qmax 60
#     done
# else
for file in ft_dir_tmp/*; do
    cp ${directory}/${file} ${directory}/fasta_dir_tmp/$(basename ${file})
done
# fi
# for file in ft_dir_tmp/*; do
#     /app/lib/vsearch/bin/vsearch --fastq_filter ${directory}/${file} --fastaout ${directory}/fasta_dir_tmp/$(basename ${file} | cut -f1 -d '.').fasta --threads 8 --fastq_qmax 60
# done

sed -i "s/\t/;/g" ${directory}/fasta_dir_tmp/*
# remove also the tags after the first ;size= and the ; after the size
sed -i 's/\(;size=[0-9]*\);.*/\1/g' ${directory}/fasta_dir_tmp/*

python3 /app/lib/python_scripts/optics.py -dir ${directory} -fasta_path "fasta_dir_tmp/*" -centers centers.csv -otu_table ${otutab} -fasta_out ${fasta_out} -sim_thr ${sim_thr} 

rm -r ft_dir_tmp concat_dir_tmp centers.csv ashure.log

# check if there are empty files
# if empty don't remove the folder to debug manually
if [ ! -s ${otutab} ]; then
    echo "OTU tab is empty"
    exit 1 # There are empty files
else
    rm -r ${dir2}
    exit 0
fi
exit 0