  
**What is it?**

This project has been initiated by the [Pawlowski group](https://genev.unige.ch/research/laboratory/Jan-Pawlowski) at the University of Geneva, Switzerland. Its aim is to bring easy access to state-of-art bioinfirmatic tools to non-specialist and/or to command-line reluctant for the processing of raw amplicon sequencing data, i.e. DNA metabarcoding, from illumina paired-end FASTQ to an annotated OTU matrix. 

SLIM is a node.js web application providing a Graphical User Interface (GUI) to interact with bioinformatic softwares. It simplifies the creation and deployment of a processing pipeline and is accessible within an internet browser over the internet. It is maintained by [Yoann Dufresne](mailto:yoann.dufresne0@gmail.com) and [Tristan Cordier](mailto:tristan.cordier@gmail.com).

The full documentation is available [here](https://github.com/yoann-dufresne/SLIM), and on the [WIKI](https://github.com/yoann-dufresne/SLIM/wiki)

—


**Can I try it?**

Yes! This website is intended to give you a demo of the tool's possibilities. The demo server has a reduced processing capacity and the upload is **limited to 2 Gb per file**. This should be enough to process a full illumina MiSeq run.

To try it, you can either :
- download this [exemple tutorial](https://github.com/trtcrd/SLIM/raw/gh-pages/assets/tuto/exemple_tuto.zip) to check by yourself the files and their required format. 

OR 

- [prepare your own data](https://github.com/yoann-dufresne/SLIM#prepare-and-upload-your-data)
- [analyse your own data](https://github.com/yoann-dufresne/SLIM#analyse-your-data)

— 

The SLIM demo server is >> [HERE](https://slim-demo.genev.unige.ch:8080) << (Please use firefox or chrome)

—

You are welcome to:

- make suggestions and report bugs [here](https://github.com/yoann-dufresne/SLIM/issues)
- send a pull request [here](https://github.com/yoann-dufresne/SLIM)

**Citation**

Dufresne, Y., Lejzerowicz, F., Apotheloz Perret-Gentil, L., Pawlowski, J., & Cordier, T. (2019). SLIM : a flexible web application for the reproducible processing of environmental DNA metabarcoding data. BMC Bioinformatics, 20(1), 88. https://doi.org/10.1186/s12859-019-2663-2


**Version history**

v0.5.3
DTD: added an option for trimming the primers at the end of the reads in (for fully overlapping pair-end reads) and a contig length filtering

v0.5.2
DADA2 beta integration, small fix on IDATAXA

v0.5.1
BUGFIX of the IDTAXA module, added wiki for the module

v0.5
Integration of the IDTAXA module

v0.4.1
Fixed the Dockerfile to fetch the latest R version and CASPER util.c file

v0.4
Added timing checkpoints in the logs of the scheduler; Added the third-party software version infos in the email

v0.3
Fixed LULU module and the otu table writing is now done by a python script

v0.2
Updated the get_dependencies script.

v0.1
First release, with third-parties versions handled within the get_dependencies_slim.sh script.















