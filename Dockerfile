# ----- Basic docker constructions -----

FROM ubuntu:20.04

# Set the working directory to /app
RUN mkdir /app
WORKDIR /app
COPY jranke.asc /app

RUN mkdir /app/lib

# Add the CRAN repos sources for install latest version of R
RUN apt-get update && apt-get install -y dirmngr gnupg apt-transport-https ca-certificates software-properties-common
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/'
#RUN sh -c 'echo "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/" >> /etc/apt/sources.list'
#RUN apt-key add /app/jranke.asc
#RUN apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'

# ----- install conda ----- #
# RUN curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
COPY lib/miniforge3 /app/lib/miniforge3
RUN bash /app/lib/miniforge3/miniforge3.sh -b
# RUN rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH="/root/miniforge3/bin:${PATH}"
# RUN conda update conda

# Install packages needed for tools
RUN apt-get update && apt-get install -y \
	libgit2-dev \
	software-properties-common \
	libcurl4-gnutls-dev \
	libxml2-dev \
	libssl-dev \
	build-essential \
	libtool \
	automake \
	zlib1g-dev \
	libbz2-dev \
	pkg-config \
	libboost-all-dev \
	pigz \
	dos2unix \
	python3-pip python3-dev python3-numpy python3-biopython \
	libc6

	RUN apt-get install -y \
	r-base-core r-recommended r-base-html r-base r-base-dev \
	libfontconfig1-dev


## solving locales issue for biopython
RUN apt-get install -y locales locales-all
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
RUN dpkg -l locales
ENV CXXFLAGS="-std=c++11"

#RUN python3 -m pip install biopython --upgrade


# ----- Libraries deployments -----

# install app dependencies
RUN apt-get install curl -y
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt install nodejs -y
COPY package.json /app
RUN npm install

# Copy libraries
COPY lib/DTD /app/lib/DTD
COPY lib/pandaseq /app/lib/pandaseq
COPY lib/vsearch /app/lib/vsearch
COPY lib/casper /app/lib/casper
COPY lib/swarm2 /app/lib/swarm2
COPY lib/swarm3 /app/lib/swarm3
# COPY lib/sratoolkit /app/lib/sratoolkit

# Compile DTD
RUN cd /app/lib/DTD && make && cd /app
# Compile pandaseq
RUN cd /app/lib/pandaseq && ./autogen.sh && ./configure && make && cd /app
# Compile vsearch
RUN cd /app/lib/vsearch && ./autogen.sh && ./configure && make && cd /app
# Compile casper
RUN cd /app/lib/casper/casper_v0.8.2 && make && cd /app
# Compile swarm2
RUN cd /app/lib/swarm2/src && make && cd /app
# Compile swarm3
RUN cd /app/lib/swarm3/src && make && cd /app

# ----- R dependancies -----

COPY lib/lulu /app/lib/lulu
COPY lib/dada2 /app/lib/dada2

RUN R -e 'install.packages("dplyr", repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("seqinr", repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("/app/lib/lulu",repos=NULL)'
RUN R -e 'install.packages("BiocManager",dependencies=TRUE,repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("ggplot2",dependencies=TRUE,repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("reshape2",dependencies=TRUE,repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("RcppParallel",dependencies=TRUE)'
RUN R -e 'install.packages("IRanges",dependencies=TRUE,repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("XVector",dependencies=TRUE,repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("BiocGenerics",dependencies=TRUE,repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'BiocManager::install("Biostrings")'
RUN R -e 'BiocManager::install("ShortRead")'
RUN R -e 'install.packages("/app/lib/dada2",repos=NULL, dependencies = TRUE)'
COPY lib/DECIPHER /app/lib/DECIPHER
RUN R -e 'install.packages("RSQLite",dependencies=TRUE,repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("/app/lib/DECIPHER",repos=NULL, dependencies = TRUE)'

# ----- install conda dependencies ----- #
RUN apt-get install -y \
	clang 

# for those packages that require conda install create a new environment
# for each to avoid incompatibilities

# ----- install chopper ----- #
RUN conda create -n chopper python=3.9 -y
# RUN echo "source activate env" >> ~/.bashrc
RUN /bin/bash -c "source activate chopper && \
	conda install -c conda-forge libgcc-ng -y && \
	conda update -c conda-forge libgcc-ng -y && \
	conda install -c conda-forge libstdcxx-ng -y && \
	conda update -c conda-forge libstdcxx-ng -y && \
	conda install -c conda-forge  zlib -y && \
	conda update -c conda-forge zlib -y && \
	conda install -c bioconda chopper=0.8.0 -y "

# ----- install msi ----- #
COPY lib/msi /app/lib/msi
RUN conda create -n msi python=3.9 -y
RUN /bin/bash -c "source activate msi && \
	apt-get update && \
	apt-get install emboss -y && \
	apt-get install time -y && \
	conda install cmake -y && \
	conda install -c conda-forge git -y && \
	conda install -c conda-forge wget -y && \
	conda install -c bioconda java-jdk -y"
# Update and install GCC and G++
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y
RUN apt-get update && apt-get install -y \
    gcc-10 \
    g++-10
# Set GCC and G++ to the new versions
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100
# # Install the latest libstdc++6
RUN apt-get install -y libstdc++6
# # Verify the installation
RUN gcc --version && g++ --version
# # Check the installed versions of libstdc++
RUN strings /usr/lib/x86_64-linux-gnu/libstdc++.so.6 | grep GLIBCXX
RUN /bin/bash -c "source activate msi && \
	conda install -c conda-forge r-base=4.1.0 -y"
# the path used to install BiocManager in metabinkit is not available.
# this is solved if we install BiocManager in the msi environment and
# in the specified path
RUN /bin/bash -c "source activate msi && \
	mkdir -p /app/lib/msi/Rlibs && \
	R -e \"install.packages('BiocManager',dependencies=TRUE,repos='https://stat.ethz.ch/CRAN/',lib='/app/lib/msi/Rlibs')\""
# RUN /bin/bash -c "source activate msi && \
# 	R -e \"!requireNamespace('BiocManager', quietly = TRUE)\""
RUN /bin/bash -c "source activate msi && \
	/app/lib/msi/scripts/msi_install.sh -i /app/lib/msi"

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

# ----- copy python_scripts -----
COPY lib/python_scripts /app/lib/python_scripts

# ----- copy R_scripts -----
COPY lib/R_scripts /app/lib/R_scripts

# ----- copy bash_scripts -----
COPY lib/bash_scripts /app/lib/bash_scripts
RUN chmod +x /app/lib/bash_scripts/*


# ----- Webserver -----

# prepare the web server
COPY server /app
COPY www/ /app/www/
COPY ssl/ /app/ssl/
EXPOSE 80

# copy npm libraries
# jquery
RUN cp node_modules/jquery/dist/jquery.js /app/www/js/jquery.js
COPY lib/jquery-autocomplete/dist/jquery.autocomplete.js /app/www/js/jquery.autocomplete.js
COPY lib/papa/papaparse.js /app/www/js/papaparse.js

# use browserify to create the bundle.js file
# RUN browserify /app/www/js/upload_SRA.js -o /app/www/js/bundle.js

# prepare data folder
RUN mkdir /app/data

RUN apt update --fix-missing 
RUN apt install vim -y


# commamd executed to run the server
CMD ["npm", "start"]
