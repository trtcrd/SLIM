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

# ----- install mamba ----- #
COPY lib/miniforge3 /tmp/miniforge3
RUN case "$(uname -m)" in \
        x86_64) miniforge_installer="/tmp/miniforge3/Miniforge3-Linux-x86_64.sh" ;; \
        aarch64|arm64) miniforge_installer="/tmp/miniforge3/Miniforge3-Linux-aarch64.sh" ;; \
        *) echo "Unsupported build architecture: $(uname -m)" >&2; exit 1 ;; \
    esac && \
    if [ ! -f "${miniforge_installer}" ]; then \
        echo "Missing Miniforge installer for $(uname -m): ${miniforge_installer}" >&2; \
        exit 1; \
    fi && \
    bash "${miniforge_installer}" -b -p /root/miniforge3 && \
    rm -rf /tmp/miniforge3 && \
    /root/miniforge3/bin/conda config --system --set channel_priority strict && \
    if ! /root/miniforge3/bin/mamba --version >/dev/null 2>&1; then \
        /root/miniforge3/bin/conda install -n base -y -c conda-forge mamba; \
    fi && \
    /root/miniforge3/bin/mamba clean -afy
ENV PATH="/root/miniforge3/bin:${PATH}"
ENV CONDA_NO_PLUGINS=true
ENV MAMBA_NO_BANNER=1


# ----- Libraries deployments -----

# install app dependencies
RUN apt-get update && apt-get install -y --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/*

# Install npm dependencies before copying server source so code-only changes can
# reuse this layer.
COPY package*.json /app/
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && \
    rm -rf /root/.npm

# Copy libraries
COPY lib/DTD /app/lib/DTD
COPY lib/vsearch /app/lib/vsearch
COPY lib/casper /app/lib/casper
COPY lib/swarm3 /app/lib/swarm3

# Compile DTD
RUN sed -i '1i #include <cstdint>' /app/lib/DTD/edit.cpp
RUN cd /app/lib/DTD && make -j$(nproc) && cd /app
# Compile vsearch
RUN cd /app/lib/vsearch && ./autogen.sh && ./configure && make -j$(nproc) && cd /app
# Compile casper
RUN cd /app/lib/casper/casper_v0.8.2 && make -j$(nproc) && cd /app
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

# ----- install mamba dependencies ----- #
RUN apt-get update && apt-get install -y --no-install-recommends \
	clang && \
    rm -rf /var/lib/apt/lists/*

# for those packages that require mamba install create a new environment
# for each to avoid incompatibilities

# ----- install chopper ----- #
RUN mamba create -n chopper -y \
    -c conda-forge \
    -c bioconda \
    python=3.9 \
    libgcc-ng \
    libstdcxx-ng \
    zlib \
    chopper=0.10.0 && \
    mamba clean -afy


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

# --- create mamba environment and install mamba packages --- #
RUN mamba create -n msi -y \
    -c conda-forge \
    -c bioconda \
        python=3.9 \
        cmake \
        git \
        wget \
        openjdk \
        r-base=4.1.0 && \
    mamba clean -afy

# --- fix BiocManager path issue --- #
RUN conda run -n msi bash -c "\
    mkdir -p /app/lib/msi/Rlibs && \
    R -e \"install.packages('BiocManager', dependencies=TRUE, repos='https://cran.rstudio.com', lib='/app/lib/msi/Rlibs')\"" && \
    rm -rf /tmp/downloaded_packages /root/.cache/R

# --- build MSI (CRITICAL: outside conda, force system compiler) --- #
RUN rm -rf /app/lib/msi/bin && \
    mkdir -p /app/lib/msi/bin && \
    CC=/usr/bin/gcc CXX=/usr/bin/g++ \
    /app/lib/msi/scripts/msi_install.sh -i /app/lib/msi
    
# ----- correction on msi source code -----
RUN sed -i 's/\/dev\/stderr/stderr_msi/g' /app/lib/msi/bin/bam_annotate.sh /app/lib/msi/bin/fastq2bam /app/lib/msi/bin/fastq_validator.sh /app/lib/msi/*/msi
RUN ! grep -Eq "metabinkit|run_blast|blastn|blast_refdb|TAXONOMY_DATA_DIR|SKIP_BLAST" /app/lib/msi/bin/msi /app/lib/msi/scripts/msi
# RUN sed -i 's/ nmembers / \$nmembers /g' /app/lib/msi/bin/msi_clustr_add_size.pl /app/lib/msi/scripts/msi_clustr_add_size.pl
RUN cd /app/lib/msi/seqtk && make && cd /app
RUN /app/lib/msi/bin/minimap2 --version && \
    /app/lib/msi/bin/racon --version
    
# ----- install ASHURE ----- #
COPY lib/ASHURE /app/lib/ASHURE

# Create ASHURE environment with a Python version compatible with pandas 1.3.x.
RUN mamba create -n ashure -y \
    -c conda-forge \
    python=3.9 \
    "cmake<4" \
    git \
    numpy=1.26.4 \
    pandas=1.3.3 \
    scikit-learn \
    hdbscan && \
    mamba clean -afy

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
# On linux-aarch64, Bioconda's SingleM/GraftM packages still depend on old
# hmmer 3.2 builds that are not available for ARM, so install HMMER from Ubuntu
# and install the Python entry points with pip.
RUN apt-get update && apt-get install -y --no-install-recommends hmmer && \
    rm -rf /var/lib/apt/lists/*

RUN if [ "$(uname -m)" = "x86_64" ]; then \
        mamba create -y \
            -c conda-forge \
            -c bioconda \
            --override-channels \
            --name singlem \
            python=3.12 \
            "singlem=0.20.3" \
            pip; \
    else \
        mamba create -y \
            -c conda-forge \
            -c bioconda \
            --override-channels \
            --name singlem \
            python=3.12 \
            pip \
            "diamond>=2.1.21" \
            "orfm>=2.1.1" \
            mfqe \
            krona \
            smafa \
            pplacer \
            "sra-tools=3.2.1" \
            ncbi-ngs-sdk \
            sqlite \
            mafft \
            seqmagick \
            cd-hit \
            fasttree \
            prodigal \
            "galah>=0.4.0" \
            coreutils \
            bash && \
        conda run -n singlem python -m pip install --no-cache-dir "singlem==0.20.3"; \
    fi && \
    mamba clean -afy

RUN conda run -n singlem python -m pip uninstall -y polars && \
    conda run -n singlem python -m pip install --no-cache-dir polars-lts-cpu

ENV PATH=/root/miniforge3/envs/singlem/bin:$PATH

# ----- install Kraken2/Bracken ----- #
# Kept at the end on purpose so existing Docker build cache is preserved while
# adding the new shotgun-metagenomics module.
RUN mamba create -n kraken2 -y \
    -c conda-forge \
    -c bioconda \
    kraken2 \
    bracken \
    fastp \
    krakentools \
    krona && \
    mamba clean -afy

ENV PATH=/root/miniforge3/envs/kraken2/bin:$PATH

# ----- install ancient-DNA targeted-reference/metaDMG tools ----- #
RUN mamba create -n ancientdna -y \
    -c conda-forge \
    -c bioconda \
    --override-channels \
    metadmg \
    ncbi-datasets-cli \
    bwa \
    samtools \
    fastp \
    pigz \
    unzip && \
    mamba clean -afy

ENV PATH=/root/miniforge3/envs/ancientdna/bin:$PATH

# ----- install mOTUs ----- #
# Kept after metaDMG so mOTUs fixes do not invalidate the ancient-DNA build cache.
RUN mamba create -n motus -y \
    -c conda-forge \
    -c bioconda \
    --override-channels \
    python=3.12 \
    "bwa=0.7.19" \
    vsearch \
    samtools \
    fastp \
    pip && \
    conda run -n motus python -m pip install --no-cache-dir "motus-tool==4.0.4" && \
    conda run -n motus python -c "import importlib.util, pathlib; p = pathlib.Path(importlib.util.find_spec('motus.motus').origin); s = p.read_text(); old_cmd = \"command: str = f'bwa mem -a -t {threads} {MOTUS_DB.get_bwa_index()} {readsfile}'\"; new_cmd = \"command: str = f'bwa mem -a -t {threads} {MOTUS_DB.get_bwa_index()} {readsfile} | samtools view -b -'\"; assert old_cmd in s or new_cmd in s, 'mOTUs map_tax command patch target not found'; s = s.replace(old_cmd, new_cmd); s = s.replace(\"pysam.AlignmentFile(process.stdout, 'r')\", \"pysam.AlignmentFile(process.stdout, 'rb')\"); p.write_text(s)" && \
    (conda run -n motus python -m pip uninstall -y polars polars-runtime-32 polars-runtime-64 polars-lts-cpu || true) && \
    conda run -n motus python -m pip install --no-cache-dir "polars[rtcompat]" && \
    mamba clean -afy

ENV PATH=/root/miniforge3/envs/motus/bin:$PATH

# ----- install isONclust3 Nanopore/PacBio tools ----- #
# Kept near the end so adding/revising this modern long-read amplicon module
# does not invalidate the older amplicon and shotgun build layers.
RUN mamba create -n isonclust3 -y \
        -c conda-forge \
        -c bioconda \
        --override-channels \
        python=3.10 \
        minimap2 \
        yacrd \
        cutadapt \
        samtools \
        htslib \
        git \
        rust \
        pip && \
    conda run -n isonclust3 cargo install isONclust3 --root /root/miniforge3/envs/isonclust3 && \
    mamba clean -afy

ENV PATH=/root/miniforge3/envs/isonclust3/bin:$PATH

# Build Racon from source instead of using the bioconda binary. Some older
# deployment CPUs crash with exit code 132 on the prebuilt Racon package.
RUN git clone --recursive --branch 1.5.0 https://github.com/lbcb-sci/racon.git /tmp/racon && \
    cmake -S /tmp/racon -B /tmp/racon/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/root/miniforge3/envs/isonclust3 \
        -DCMAKE_C_COMPILER=/usr/bin/gcc \
        -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
        -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" \
        -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
        -Dracon_enable_cuda=OFF && \
    cmake --build /tmp/racon/build --parallel $(nproc) && \
    install -m 0755 /tmp/racon/build/bin/racon /root/miniforge3/envs/isonclust3/bin/racon && \
    /root/miniforge3/envs/isonclust3/bin/racon --version && \
    rm -rf /tmp/racon

# ----- copy python_scripts -----
COPY lib/python_scripts /app/lib/python_scripts

# ----- copy R_scripts -----
COPY lib/R_scripts /app/lib/R_scripts

# updates on biopython
RUN python3 -m pip install --no-cache-dir biopython --upgrade

# ----- Webserver -----
# prepare the web server
COPY server /app
COPY www/ /app/www/
COPY man/ /app/man/
COPY ssl/ /app/ssl/
EXPOSE 80

# Copy browser libraries from installed packages and vendored sources.
RUN cp node_modules/jquery/dist/jquery.js /app/www/js/jquery.js
COPY lib/jquery-autocomplete/dist/jquery.autocomplete.js /app/www/js/jquery.autocomplete.js
COPY lib/papa/papaparse.js /app/www/js/papaparse.js

# Resolve build-time version placeholders from the software installed in this image.
RUN bash /app/update_versions.sh

# use browserify to create the bundle.js file
# RUN browserify /app/www/js/upload_SRA.js -o /app/www/js/bundle.js

# ----- copy bash_scripts -----
COPY lib/bash_scripts /app/lib/bash_scripts
RUN chmod +x /app/lib/bash_scripts/*

# prepare data folder
RUN mkdir /app/data


# command executed to run the server
CMD ["bash", "/app/start_slim_server.sh"]
