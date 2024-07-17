# ----- Basic docker constructions -----

FROM ubuntu:20.04

# Set the working directory to /app
RUN mkdir /app
WORKDIR /app
COPY jranke.asc /app

RUN mkdir /app/lib

# Add the CRAN repos sources for install latest version of R
RUN apt-get update && apt-get install -y dirmngr gnupg apt-transport-https ca-certificates software-properties-common
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/'
#RUN sh -c 'echo "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/" >> /etc/apt/sources.list'
#RUN apt-key add /app/jranke.asc
#RUN apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'

# ----- install conda ----- #
# RUN curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
COPY lib/miniconda /app/lib/miniconda
RUN bash /app/lib/miniconda/Miniconda3-latest-Linux-x86_64.sh -b
# RUN rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH="/root/miniconda3/bin:${PATH}"
RUN conda update conda

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

# RUN apt-get install curl m4 -y
# RUN curl -OL http://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz && \
#     tar -xzvf autoconf-2.71.tar.gz && \
#     cd autoconf-2.71 && \
#     ./configure && make && make install && \
#     cd ..
# RUN curl -OL https://github.com/pkgconf/pkgconf/archive/refs/tags/pkgconf-2.2.0.tar.gz && \
# 	tar -xzvf pkgconf*tar.gz && cd pkgconf-pkgconf* && ls -lhtr && /bin/bash ./autogen.sh && make && make install && cd ..
RUN apt-get install -y \
	# pkgconf-2.2.0 \
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
COPY lib/sratoolkit /app/lib/sratoolkit

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
# export path of the binnaries from sratoolkit
RUN export PATH="$PATH:/app/lib/sratoolkit/bin/"

# Copy Python and R scripts
COPY lib/python_scripts /app/lib/python_scripts
COPY lib/R_scripts /app/lib/R_scripts

# ----- R dependancies -----

COPY lib/lulu /app/lib/lulu
COPY lib/dada2 /app/lib/dada2

# RUN R -e 'getwd()'
###RUN apt-get -y build-dep libcurl4-gnutls-dev
###RUN apt-get -y install libcurl4-gnutls-dev
# RUN R -e 'install.packages("devtools", repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("dplyr", repos="https://stat.ethz.ch/CRAN/")'
RUN R -e 'install.packages("seqinr", repos="https://stat.ethz.ch/CRAN/")'
# RUN R -e 'library(devtools);install_github("tobiasgf/lulu")'
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
# RUN R -e 'BiocManager::install("DECIPHER")'
# RUN R -e 'BiocManager::install("dada2")'
# RUN R -e 'install.packages("https://github.com/benjjneb/dada2/archive/refs/tags/v1.16.tar.gz", repos = NULL, type = "source")'#
RUN R -e 'install.packages("/app/lib/dada2",repos=NULL, dependencies = TRUE)'
# RUN R -e 'library(devtools);devtools::install_github("benjjneb/dada2", ref="v1.16")'
RUN R -e 'BiocManager::install("DECIPHER")'
# RUN R -e 'install.packages("https://www.bioconductor.org/packages/3.11/bioc/src/contrib/Archive/DECIPHER/DECIPHER_2.16.0.tar.gz", repos = NULL, type = "source")'#

# ----- more installations ----- #
# RUN apt-get update && apt-get install -y wget
# RUN wget https://github.com/wdecoster/chopper/releases/download/v0.8.0/chopper-linux.zip && \
# 	unzip chopper-linux.zip && \
# 	mv chopper /app/lib/. && \
# 	chmod +x /app/lib/chopper

# ----- install broserify ----- #
# RUN npm install -g browserify

# ----- install vim for manual editing (remove after during developing) ----- #
# RUN apt-get install vim -y

# ----- install nextflow ----- #
# I'm having problems installing it
# RUN curl -s https://get.sdkman.io | bash && source "/root/.sdkman/bin/sdkman-init.sh" && sdk install java 17.0.10-tem
# RUN curl -s https://get.nextflow.io | bash && chmod +x nextflow && mv nextflow /app/lib/.

# # ----- install conda ----- #
# # RUN curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
# COPY lib/miniconda /app/lib/miniconda
# RUN bash /app/lib/miniconda/Miniconda3-latest-Linux-x86_64.sh -b
# # RUN rm Miniconda3-latest-Linux-x86_64.sh
# ENV PATH="/root/miniconda3/bin:${PATH}"
# RUN conda update conda
# ----- install conda dependencies ----- #
RUN apt-get install -y \
	clang 

# ----- install conda packages ----- #
RUN conda create -n env python=3.9 -y
RUN echo "source activate env" >> ~/.bashrc
RUN /bin/bash -c "source activate env && \
	conda install -c conda-forge libgcc-ng && \
	conda update -c conda-forge libgcc-ng && \
	conda install -c conda-forge libstdcxx-ng && \
	conda update -c conda-forge libstdcxx-ng && \
	conda install -c conda-forge  zlib && \
	conda update -c conda-forge zlib && \
	conda install -c bioconda chopper=0.8.0"


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
