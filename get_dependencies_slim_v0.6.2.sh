#!/bin/sh


if [ ! -d "lib" ]; then
	mkdir lib
fi
cd lib/


# jquery autocomplete
if [ ! -d "jquery-autocomplete" ]; then
	mkdir jquery-autocomplete
	# git clone https://github.com/devbridge/jQuery-Autocomplete.git jquery-autocomplete
	cd jquery-autocomplete
	# git pull
	curl -OL https://github.com/devbridge/jQuery-Autocomplete/archive/v1.4.7.tar.gz
	tar -xzvf v1.4.7.tar.gz
	mv jQuery-Autocomplete-1.4.7/* .
	cd ..
else
	echo "jQuery already there..."
fi

# Papaparser
if [ ! -d "papa" ]; then
	mkdir papa
	#git clone https://github.com/mholt/PapaParse.git papa
	cd papa
	#git pull
	curl -OL https://github.com/mholt/PapaParse/archive/4.4.0.tar.gz
	tar -xzvf 4.4.0.tar.gz
	mv PapaParse-4.4.0/* .
	cd ..
else
	echo "PAPAparser already there..."
fi


# Demultiplexing tool # no stable release yet... oops
if [ ! -d "DTD" ]; then
	mkdir DTD
	cd DTD
	# git clone https://github.com/yoann-dufresne/DoubleTagDemultiplexer.git DTD/
	curl -OL https://github.com/yoann-dufresne/DoubleTagDemultiplexer/archive/f687329ac846193605af97ef2b3f65d1bf5bce04.zip
	unzip f687329ac846193605af97ef2b3f65d1bf5bce04.zip
	mv DoubleTagDemultiplexer-f687329ac846193605af97ef2b3f65d1bf5bce04/* .
	# git pull
	cd ..
else
	echo "DTD is already there..."
fi


# Pandaseq
if [ ! -d "pandaseq" ]; then
	mkdir pandaseq
	#git clone https://github.com/neufeld/pandaseq.git pandaseq/
	cd pandaseq
	#git pull
	curl -OL https://github.com/neufeld/pandaseq/archive/v2.11.tar.gz
	tar -xzvf v2.11.tar.gz
	mv pandaseq-2.11/* .
	cd ..
else
	echo "PANDAseq is already there..."
fi


# Vsearch
if [ ! -d "vsearch" ]; then
	mkdir vsearch
	# git clone https://github.com/torognes/vsearch.git vsearch/
	cd vsearch
	curl -OL https://github.com/torognes/vsearch/archive/v2.8.0.tar.gz
	tar -xzvf v2.8.0.tar.gz
	mv vsearch-2.8.0/* .
	# git pull
	cd ..
else
	echo "VSEARCH is already there..."
fi


# QIIME 2
# docker pull qiime2/core:201

# Casper # no repos... oops
cd casper
if [ ! -d "casper_v0.8.2" ]; then
	tar -xf casper_v0.8.2.tar.xz
fi
cd ..


# Swarm2
if [ ! -d "swarm2" ]; then
	mkdir swarm2
	# git clone https://github.com/torognes/swarm.git swarm/
	cd swarm2
	#git pull
	curl -OL https://github.com/torognes/swarm/archive/v2.2.2.tar.gz
	tar -xzvf v2.2.2.tar.gz
	mv swarm-2.2.2/* .
	cd ..
else
	echo "SWARM2 is already there..."
fi

# Swarm3
if [ ! -d "swarm3" ]; then
	mkdir swarm3
	# git clone https://github.com/torognes/swarm.git swarm/
	cd swarm3
	#git pull
	curl -OL https://github.com/torognes/swarm/archive/v3.1.4.tar.gz
	tar -xzvf v3.1.4.tar.gz
	mv swarm-3.1.4/* .
	cd ..
else
	echo "SWARM3 is already there..."
fi

# lulu
if [ ! -d "lulu" ]; then
	git clone https://github.com/tobiasgf/lulu
else
	echo "lulu is already there..."
fi


# DADA2
if [ ! -d "dada2" ]; then
	mkdir dada2
	cd dada2
	curl -OL https://github.com/benjjneb/dada2/archive/refs/tags/v1.16.tar.gz
	tar -xzvf v1.16.tar.gz
	mv dada2-1.16/* .
	cd ..
else
	echo "dada2 is already there..."
fi


# # SRAtoolkit
# if [ ! -d "sratoolkit" ]; then
# 	mkdir sratoolkit
# 	cd sratoolkit
# 	wget --output-document sratoolkit.tar.gz https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.0.7/sratoolkit.3.0.7-ubuntu64.tar.gz
# 	tar -vxzf sratoolkit.tar.gz
# 	mv sratoolkit.3.0.7-ubuntu64/* .
# 	cd ..
# else
# 	echo "sratoolkit is already there..."
# fi

# DECIPHER
if [ ! -d "DECIPHER" ]; then
	mkdir DECIPHER
	cd DECIPHER
	curl -OL https://www.bioconductor.org/packages/3.11/bioc/src/contrib/Archive/DECIPHER/DECIPHER_2.16.0.tar.gz
	tar -vxzf DECIPHER_2.16.0.tar.gz
	mv DECIPHER/* .
	cd ..
else
	echo "DECIPHER is already there..."
fi


# msi
if [ ! -d "msi" ]; then
	# when issue is fixed, use the following
	# mkdir msi
	# cd msi
	# curl -OL https://github.com/nunofonseca/msi/archive/refs/tags/0.3.7.tar.gz
	# tar -vxzf 0.3.7.tar.gz
	# mv msi-0.3.7/* .
	git clone https://github.com/adriantich/msi.git
	cd msi
	git clone https://github.com/adriantich/fastq_utils.git
	sed -i 's/git clone/\# git clone/g' scripts/msi_install.sh
	sed -i 's/ nmembers / \$nmembers /g' /app/lib/msi/scripts/msi_clustr_add_size.pl
	git clone https://github.com/lh3/seqtk.git
	cd ..
else
	echo "msi is already there..."
fi

# ASHURE
if [ ! -d "ASHURE" ]; then
	mkdir ASHURE
	cd ASHURE
	curl -OL https://github.com/BBaloglu/ASHURE/archive/refs/tags/v1.0.0.tar.gz
	tar -vxzf v1.0.0.tar.gz
	mv ASHURE-1.0.0/* .
	# download spoa
	curl -OL https://github.com/rvaser/spoa/archive/refs/tags/4.1.0.tar.gz
	tar -vxzf 4.1.0.tar.gz
	mv spoa-4.1.0 spoa
	cd ..
else
	echo "ASHURE is already there..."
fi


# miniconda
if [ ! -d "miniforge3" ]; then
	mkdir miniforge3
	cd miniforge3
	curl -OL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh 
	mv Miniforge3-Linux-x86_64.sh miniforge3.sh
	cd ..
else
	echo "miniforge3 is already there..."
fi


