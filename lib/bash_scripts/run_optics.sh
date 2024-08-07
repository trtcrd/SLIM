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
export PATH=$PATH:/app/lib/msi/bin/:/app/lib/ASHURE/spoa/build/bin/

# export paths to ashure
export PATH=$PATH/app/lib/ASHURE/src/:


source activate ashure

cd ${directory}

mkdir -p ft_dir_tmp
cp ${fasta_files} ft_dir_tmp/.

mkdir -p concat_dir_tmp
cat ft_dir_tmp/* >concat_dir_tmp/concatenated.fastq
python3 /app/lib/ASHURE/src/ashure.py clst -i concat_dir_tmp/concatenated.fasta -o centers.csv -N ${clst_N} -cs ${clst_csize} -tm ${clst_th_m} -ts ${clst_th_s} -iter ${clst_N_iter} -r

python3 /app/lib/python_scripts/optics.py -dir ${directory} -fasta_path "ft_dir_tmp/*" -centers centers.csv -otu_table ${otutab} -fasta_out ${fasta_out} -sim_thr ${sim_thr} 

rm -r ft_dir_tmp concat_dir_tmp centers.csv ashure.log
exit 0