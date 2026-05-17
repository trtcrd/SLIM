# ----- Basic docker constructions -----

FROM ubuntu:24.04

# Install packages needed for tools
RUN apt-get update && apt-get install -y --no-install-recommends \
	libgit2-dev \
	software-properties-common \
	libcurl4-gnutls-dev \
	libxml2-dev \
	libssl-dev \
	build-essential \
	gcc \
	g++ \
	make \
	cmake \
	autoconf \
	automake \
	libtool \
	automake \
	zlib1g-dev \
	libbz2-dev \
	pkg-config \
	libboost-all-dev \
	pigz \
	dos2unix \
	python3-pip python3-dev python3-numpy python3-biopython \
	libc6 && \
    rm -rf /var/lib/apt/lists/*
# libcurl4-openssl-dev

RUN apt-get update && apt-get install -y --no-install-recommends \
	r-base-core r-recommended r-base-html r-base r-base-dev \
	ca-certificates \
    curl \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

## solving locales issue for biopython
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV CXXFLAGS="-std=c++11"


RUN apt-get update && apt-get install -y --no-install-recommends --reinstall \
    ca-certificates curl libcurl4-openssl-dev && \
    update-ca-certificates --fresh && \
    rm -rf /var/lib/apt/lists/*
    

# ---- R packages (CRAN) ----
RUN R -e 'install.packages(c( \
"dplyr", \
"seqinr", \
"ggplot2", \
"reshape2", \
"RcppParallel", \
"memoise", \
"rmarkdown", \
"pkgload", \
"fs", \
"htmlwidgets", \
"RSQLite", \
"BiocManager" \
), dependencies=TRUE, repos="https://cran.rstudio.com")' && \
    rm -rf /tmp/downloaded_packages /root/.cache/R

# ---- Bioconductor ----
RUN R -e 'BiocManager::install(c( \
"BiocGenerics", \
"IRanges", \
"XVector", \
"Biostrings", \
"ShortRead" \
), ask=FALSE, update=FALSE)' && \
    rm -rf /tmp/downloaded_packages /root/.cache/R


# Set the working directory to /app
RUN mkdir /app
WORKDIR /app
COPY jranke.asc /app

RUN mkdir /app/lib

# Add the CRAN repos sources for install latest version of R
RUN apt-get update && apt-get install -y --no-install-recommends dirmngr gnupg apt-transport-https ca-certificates software-properties-common && \
    rm -rf /var/lib/apt/lists/*
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/' && \
    rm -rf /var/lib/apt/lists/*
#RUN sh -c 'echo "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/" >> /etc/apt/sources.list'
#RUN apt-key add /app/jranke.asc
#RUN apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'

# ----- install conda ----- #
COPY lib/miniforge3/miniforge3.sh /tmp/miniforge3.sh
RUN bash /tmp/miniforge3.sh -b && \
    rm -f /tmp/miniforge3.sh && \
    /root/miniforge3/bin/conda clean -afy
ENV PATH="/root/miniforge3/bin:${PATH}"
ENV CONDA_NO_PLUGINS=true
# RUN conda update conda


# ----- Libraries deployments -----

# install app dependencies
RUN apt-get update && apt-get install -y --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/*

# Copy libraries
COPY lib/DTD /app/lib/DTD
COPY lib/pandaseq /app/lib/pandaseq
COPY lib/vsearch /app/lib/vsearch
COPY lib/casper /app/lib/casper
# COPY lib/swarm2 /app/lib/swarm2
COPY lib/swarm3 /app/lib/swarm3
# COPY lib/sratoolkit /app/lib/sratoolkit

# Compile DTD
RUN sed -i '1i #include <cstdint>' /app/lib/DTD/edit.cpp
RUN cd /app/lib/DTD && make -j$(nproc) && cd /app
# Compile pandaseq
# RUN cd /app/lib/pandaseq && ./autogen.sh && ./configure && make -j$(nproc) && cd /app
# Compile vsearch
RUN cd /app/lib/vsearch && ./autogen.sh && ./configure && make -j$(nproc) && cd /app
# Compile casper
RUN cd /app/lib/casper/casper_v0.8.2 && make -j$(nproc) && cd /app
# Compile swarm2
# RUN cd /app/lib/swarm2/src && make -j$(nproc) && cd /app
# Compile swarm3
RUN cd /app/lib/swarm3/src && make -j$(nproc) && cd /app

# ----- R dependancies -----

COPY lib/lulu /app/lib/lulu
COPY lib/dada2 /app/lib/dada2
COPY lib/DECIPHER /app/lib/DECIPHER

RUN R -e 'install.packages("/app/lib/dada2",repos=NULL, dependencies = TRUE)' && \
    rm -rf /tmp/downloaded_packages /root/.cache/R
RUN R -e 'install.packages("/app/lib/DECIPHER",repos=NULL, dependencies = TRUE)' && \
    rm -rf /tmp/downloaded_packages /root/.cache/R

# ----- install conda dependencies ----- #
RUN apt-get update && apt-get install -y --no-install-recommends \
	clang && \
    rm -rf /var/lib/apt/lists/*

# for those packages that require conda install create a new environment
# for each to avoid incompatibilities

# ----- install chopper ----- #
RUN conda create --solver=classic -n chopper -y \
    -c conda-forge \
    -c bioconda \
    python=3.9 \
    libgcc-ng \
    libstdcxx-ng \
    zlib \
    chopper=0.8.0 && \
    conda clean -afy


# ----- install msi ----- #
COPY lib/msi /app/lib/msi

# --- system dependencies (DO NOT put inside conda) --- #
RUN apt-get update && apt-get install -y --no-install-recommends \
    emboss \
    time \
    software-properties-common \
    libstdc++6 \
    build-essential \
    wget \
    git \
    cmake \
    default-jdk && \
    rm -rf /var/lib/apt/lists/*

# --- create conda environment and install conda packages --- #
RUN conda create --solver=classic -n msi -y \
    -c conda-forge \
    -c bioconda \
        python=3.9 \
        cmake \
        git \
        wget \
        openjdk \
        r-base=4.1.0 && \
    conda clean -afy

# --- fix BiocManager path issue --- #
RUN conda run -n msi bash -c "\
    mkdir -p /app/lib/msi/Rlibs && \
    R -e \"install.packages('BiocManager', dependencies=TRUE, repos='https://cran.rstudio.com', lib='/app/lib/msi/Rlibs')\"" && \
    rm -rf /tmp/downloaded_packages /root/.cache/R

# --- build MSI (CRITICAL: outside conda, force system compiler) --- #
RUN CC=/usr/bin/gcc CXX=/usr/bin/g++ \
    /app/lib/msi/scripts/msi_install.sh -i /app/lib/msi
    
# ----- correction on msi source code -----
RUN sed -i 's/\/dev\/stderr/stderr_msi/g' /app/lib/msi/bin/bam_annotate.sh /app/lib/msi/bin/fastq2bam /app/lib/msi/bin/fastq_validator.sh /app/lib/msi/*/msi /app/lib/msi/exe/metabinkit_blastgendb 
# RUN sed -i 's/ nmembers / \$nmembers /g' /app/lib/msi/bin/msi_clustr_add_size.pl /app/lib/msi/scripts/msi_clustr_add_size.pl
RUN cd /app/lib/msi/seqtk && make && cd /app
    
# ----- install ASHURE ----- #
COPY lib/ASHURE /app/lib/ASHURE

# Create ASHURE environment with a Python version compatible with pandas 1.3.x.
RUN conda create --solver=classic -n ashure -y \
    -c conda-forge \
    python=3.9 \
    "cmake<4" \
    git \
    numpy=1.26.4 \
    pandas=1.3.3 \
    scikit-learn \
    hdbscan && \
    conda clean -afy

# Build spoa.
RUN cd /app/lib/ASHURE/spoa && \
    conda run -n ashure cmake -B build -DCMAKE_BUILD_TYPE=Release && \
    conda run -n ashure make -C build

# Install/check ASHURE.
RUN cd /app/lib/ASHURE && \
    chmod +x src/ashure.py && \
    conda run -n ashure ./src/ashure.py run -h

# Check ASHURE commands.
RUN conda run -n ashure /app/lib/ASHURE/src/ashure.py prfg -h && \
    conda run -n ashure /app/lib/ASHURE/src/ashure.py fgs -h && \
    conda run -n ashure /app/lib/ASHURE/src/ashure.py msa -h && \
    conda run -n ashure /app/lib/ASHURE/src/ashure.py fpmr -h


# ----- install SingleM ----- #
RUN conda create --solver=classic -y \
    -c conda-forge \
    -c bioconda \
    --override-channels \
    --name singlem \
    python=3.12 \
    "singlem=0.20.3" \
    pip && \
    conda clean -afy

RUN conda run -n singlem python -m pip uninstall -y polars && \
    conda run -n singlem python -m pip install --no-cache-dir polars-lts-cpu

ENV PATH=/root/miniforge3/envs/singlem/bin:$PATH

# ----- copy python_scripts -----
COPY lib/python_scripts /app/lib/python_scripts

# ----- copy R_scripts -----
COPY lib/R_scripts /app/lib/R_scripts

# ----- copy bash_scripts -----
COPY lib/bash_scripts /app/lib/bash_scripts
RUN chmod +x /app/lib/bash_scripts/*

# updates on biopython
RUN python3 -m pip install --no-cache-dir biopython --upgrade

# ----- Webserver -----
# prepare the web server
COPY server /app
COPY www/ /app/www/
COPY ssl/ /app/ssl/
EXPOSE 80

# copy npm libraries
COPY package*.json /app/
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && \
    npm cache clean --force

# jquery
RUN cp node_modules/jquery/dist/jquery.js /app/www/js/jquery.js
COPY lib/jquery-autocomplete/dist/jquery.autocomplete.js /app/www/js/jquery.autocomplete.js
COPY lib/papa/papaparse.js /app/www/js/papaparse.js

# use browserify to create the bundle.js file
# RUN browserify /app/www/js/upload_SRA.js -o /app/www/js/bundle.js

# prepare data folder
RUN mkdir /app/data



# commamd executed to run the server
CMD ["npm", "start"]
