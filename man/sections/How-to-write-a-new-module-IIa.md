# How to write a new module II: ASHURE example, concept and installation
 
Edited by Adrià:

Here I will explain how I created ASHURE Module using existing Modules as templates. 

# Conceptual design
Before starting with the coding you need to conceptualize how the Module will look and how it will behave. The former should serve the latter and since this platform is not meant to be beautiful but useful, we need to focus on such porpoise. 

In this case ashure allows to use as a configuration file with all the specifications of the pipeline as input and by using it, ashure would know what to do. However, I do not wish the user to create this file, if that would be the case, then to run ashure from the command line it wouldn't be that trouble. I wanted to give the User the minimum user settable fields to make it simple. Thus I decided to have the following fields:

__Inputs:__

    Input fastq files

    Primers file

    Additional inputs, "Options":

    Reads length; Min cluster size; Threshold for clustering; Partitions to split seqs; Size of Sequence subsample; Iterations for clustering

__Outputs:__

    Consensus sequences

    Trimmed consensus

    Cluster center

# Installation
Once I have in mind what my module will do, I need to familiarise with the program and to know the dependencies required. In this case I concluded that as this is a full pipeline itself with many dependencies, a conda environment was the best option to use. 

For the Installation you will need to modify two files:

* [Get_dependencies.sh](https://github.com/adriantich/SLIM/blob/master/get_dependencies_slim_v0.6.2.sh): If the software can be downloaded or cloned from a repository you can add it here other than using devtools for instance for R packages. 

For the example I added:
```
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
```
That will download ASHURE and spoa if they are not already downloaded.

* [Dockerfile](https://github.com/adriantich/SLIM/blob/master/Dockerfile):
This file will be used by Docker or podman to build the container and will have the instructions to install the software required. This part can be the most tricky due to dependency conflicts or errors that scape from my knowledge that somehow have been solved trying to build the container again. Internet connection maybe? I did:
```
# ----- install conda ----- #
# RUN curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
COPY lib/miniconda /app/lib/miniconda
RUN bash /app/lib/miniconda/miniconda.sh -b
# RUN rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH="/root/miniconda3/bin:${PATH}"
# RUN conda update conda
```
This will install conda. Be aware that the first line commented was changed by incorporing the miniconda installer in SLIM repository to ensure the version. If changed, the other software should be checked for compatibility. Also be awared that due to Anaconda fee program, this will be changed by miniforge at some point.

```
# ----- install ASHURE ----- #
COPY lib/ASHURE /app/lib/ASHURE
RUN conda create -n ashure python=3.9 -y
# minimap2 has been installed with msi and its located at /app/lib/msi/bin/minimap2
# RUN /bin/bash -c "source activate ashure && \
# 	/app/lib/msi/bin/minimap2"
# install cmake and git in ashure environment
RUN /bin/bash -c "source activate ashure && \
conda install -c conda-forge cmake git -y"
# install spoa
RUN /bin/bash -c "source activate ashure && \
	cd /app/lib/ASHURE/spoa && \
	cmake -B build -DCMAKE_BUILD_TYPE=Release && \
	make -C build && cd /app"
# install python modules for ASHURE
	# due to a deprecation error, pandas need to be previous to 1.4.0
RUN /bin/bash -c "source activate ashure && \
	pip install pandas==1.3.3 && \
	pip install scikit-learn && \
	pip install hdbscan &&\
	pip install numpy==1.26.4"
# install ashure
RUN /bin/bash -c "source activate ashure && \
	cd /app/lib/ASHURE && \
	chmod +x src/ashure.py && \
	src/ashure.py run -h && cd /app"
# check if ashure commands are working
RUN /bin/bash -c "source activate ashure && \
	/app/lib/ASHURE/src/ashure.py prfg -h && \
	/app/lib/ASHURE/src/ashure.py fgs -h && \
	/app/lib/ASHURE/src/ashure.py msa -h && \
	/app/lib/ASHURE/src/ashure.py fpmr -h"
```
This will install all the dependencies and ASHURE within the "ashure" conda environment. Thus I will need to activate the environment when calling the program.

# Check installation
Once you think that everything is working is time to check that it is indeed. In this case I will explain how to do it with podman as it is the default for the [start_slim.sh](https://github.com/adriantich/SLIM/blob/master/start_slim_v0.6.2.sh).

Build the container by using the [start_slim.sh](https://github.com/adriantich/SLIM/blob/master/start_slim_v0.6.2.sh) script:
```
>bash start_slim_v0.6.2.sh
```
Once it finishes without errors, the container should be running. Then run:
```
>podman ps
CONTAINER ID  IMAGE                  COMMAND     CREATED       STATUS           PORTS                 NAMES
89b89fd2cfcf  localhost/slim:latest  npm start   33 hours ago  Up 33 hours ago  0.0.0.0:8080->80/tcp  goofy_nobel
```
Here the container name is goofy_nobel. We can use this to enter the container from the server:
```
podman exec -i  goofy_nobel -t /bash
```
And once inside we can try to run ashure, by activating the environment and executing the help of the program.
```
# export paths
>export PATH=$PATH:/root/.local/bin/:
# export paths to minimap2 and spoa
>export PATH=$PATH/app/lib/msi/bin/:/app/lib/ASHURE/spoa/build/bin/
# export paths to ashure
>export PATH=$PATH/app/lib/ASHURE/src/:
# activate and run help
>source activate ashure
>python3 /app/lib/ASHURE/src/ashure.py -h
usage: ashure.py [-h] [-spoa SPOA_PATH] [-minimap2 MINIMAP2_PATH] [--low_mem] {run,prfg,fgs,msa,fpmr,clst} ...

aSHuRE: a consensus error correction pipeline for nanopore sequencing

optional arguments:
  -h, --help            show this help message and exit
  -spoa SPOA_PATH       path to spoa executable
  -minimap2 MINIMAP2_PATH
                        path to minimap2 executable
  --low_mem             enable optimizations that reduce RAM used

subcommands:
  {run,prfg,fgs,msa,fpmr,clst}
    run                 suboptions for running the pipeline
    prfg                suboptions for pseudo reference generator
    fgs                 suboptions for repeat fragment finder
    msa                 suboptions for multi-sequence alignment
    fpmr                suboptions for matching primers to consensus reads
    clst                suboptions for clustering

```

