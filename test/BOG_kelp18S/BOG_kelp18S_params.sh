#!/usr/bin/env bash

DEBUG1="YES"
################################################################################
# INPUT
################################################################################
# What is the file path to the directory containing all of the libraries/reads?
# In this version the PARENT_DIR is passed in to banzai_BOG18S.sh
#PARENT_DIR="{$HOME_DIR}/raw/test_data/B"
#W:\Regions\NortheastPacific\MBON\BOG_eDNA_Z_July2015\BOG_18S_Z_Indexed\BOG_18S_Z_indexed_Seqs
PARENT_DIR="/BOG_Archive/Stanford_Extraction_Methods/Stanford_18S_Indexed/Stanford_18S_Indexed_Seqs/C"

# Use test direcory for source data and for work area
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOME_DIR=$(dirname $CURR_DIR)

# Where is the sequencing metadata file? (SEE FORMATTING GUIDELINES IN README!)
#SEQUENCING_METADATA="{$HOME_DIR}/raw/test_data/test_data_metadata.csv"
#SEQUENCING_METADATA="{$HOME_DIR}/scripts/BOG18S_eDNA_metadata_one_lib_test.csv"
SEQUENCING_METADATA="$CURR_DIR/BOG_kelp18S_metadata_test.csv"


################################################################################
# OUTPUT
################################################################################
# This script will generate a directory (folder) containing the output of the script.
# Where do you want this new folder to go?
ANALYSIS_DIRECTORY="$HOME_DIR/processed"

# You can optionally specify a folder into which the script copies a PDF containing some results.
# The pdf is created by default in the analysis folder specified above, but
# if you set this to your DropBox or Google Drive Folder, you can check it out from anywhere.
OUTPUT_PDF_DIR="$HOME_DIR/processed"


################################################################################
# METADATA DETAILS
################################################################################
# TODO grab this from a fragment_size column in the sequencing metadata file
### ***** REMEMBER TO WATCH FOR ZEROS WHEN IMPLEMENTING THIS!
# Is there a column in the metadata file for fragment size?
frag_size_in_metadata="NO"
# If YES, what is the name?
frag_size_column="fragment_size_BA"

# If fragment size is not specified in metadata, specify it here.
# What is the maximum expected length of the fragment of interest?
# This is the length of the fragments input into library prep --
# i.e. with (indexed) primers, but without library index or sequencing adapters
#LENGTH_FRAG="182"
# estimate re: Shannon
LENGTH_FRAG="600"

# Your metadata must have a column corresponding to the subfolders containing the raw reads.
# In order to make this flexible across both multiple and single library preps, you must include this even if you only sequenced one library (sorry!).
READ_LIB_FROM_SEQUENCING_METADATA="YES"
LIBRARY_COLUMN_NAME="library"
LIBRARY_TAG_COMBO_COLUMN_NAME="library_tag_combo"
################################################################################
# MERGE PAIRED READS
################################################################################
# For more information on these parameters, type into a terminal window: pear -help
# Bokulich recommends:
# Quality_Threshold=3, r=3 (PEAR only considers r=2), UNCALLEDMAX=0
# TRIMMIN= 0.75 * LENGTH_READ # this is hard-coded in the script banzai.sh

# --quality-threshold
#Quality_Threshold=15
Quality_Threshold=15

# proportion of allowed uncalled bases (--max-uncalled-base)
#UNCALLEDMAX=0
UNCALLEDMAX=1
# which statistical test (--test-method)
TEST=1
#TEST=1
# cutoff p-value (--p-value)
PVALUE=0.01
#PVALUE=0.05

# scoring method type (--score-method)
SCORING=2
#SCORING=1

# What is the minimum final sequence length you'd like to include in analyses?
# Bokulich et al. recommend 75% of the expected fragment size.
# this includes PCR primers, but not anything ligated on during library prep.
min_seq_length=150
#min_seq_length=1
# equivalent variable was TRIMMIN

################################################################################
# QUALITY FILTERING
################################################################################
# Substantial quality filtering (e.g. trimming, minimum length, etc) is performed by PEAR during read merging.
# You may also want to exclude sequences containing more than a specified threshold of 'expected errors'
# This number is equal to the sum of the error probabilities.
# The only software that currently implements this is usearch, but it requires breaking up files larger than ~4GB
# I think this can be written in python relatively easily, but I haven't gotten to it yet.
# For more information on this parameter, Google the usearch help
Perform_Expected_Error_Filter="YES" # [YES|NO]
Max_Expected_Errors="0.5"

################################################################################
# HOMOPOLYMERS
################################################################################
# Would you like to remove reads containing runs of consecutive identical bases (homopolymers)?
REMOVE_HOMOPOLYMERS="NO"
# What is the maximum homopolymer length you're willing to accept?
# Reads containing runs of identical bases longer than this will be discarded.
HOMOPOLYMER_MAX="7"


################################################################################
# DEMULTIPLEXING
################################################################################
# Specify the nucleotide sequences that differentiate multiplexed samples ("tags", and in the case of the Kelly Lab, primer tags)
# You can grab these from the file specified above (SEQUENCING_METADATA) by specifying the column name holding tags.
# Or you can specify a text file containing only these tags (choose "NO", and then specify path to the tag file).
# This file should be simply a list of sequences, one per line, of each of the tags, WITH A TRAILING NEWLINE!
# To make a trailing newline, make sure when you open the file, you have hit enter after the final sequence.
DEMULTIPLEX_DATA="NO"
TAG_COLUMN_NAME="tag_sequence"
R1_COLUMN_NAME="R1"
R2_COLUMN_NAME="R2"
# How many nucleotides pad the 5' end of the tag sequence?
# TODO build in flexibility (this number is unused right now)
TAG_Ns="3"
# What is the maximum number of Ns to allow at the end of a sequence before a tag is reached?
# TAG_N_MAX="9" # THIS IS NOT WORKING YET. SET TO DEFAULT 9

# Should demultiplexed samples be concatenated for annotation as a single unit? (Each read can still be mapped back to samples)
# Recommended: YES
CONCATENATE_SAMPLES="YES"

################################################################################
# PRIMER REMOVAL
################################################################################
# Specify the primers used to generate these amplicons.
# As with the multiplex tags, Banzai will grab these from the file SEQUENCING_METADATA.
# You must indicate the column names of the forward and reverse primers
PRIMER_1_COLUMN_NAME="primer_sequence_F"
PRIMER_2_COLUMN_NAME="primer_sequence_R"

# What proportion of mismatches are you willing to accept when looking for primers?
# Recommended: "0.10"
PRIMER_MISMATCH_PROPORTION="0.10"

ColumnName_SampleName="sample_name"
ColumnName_SampleType="sample_type"

################################################################################
# CLUSTER OTUs
################################################################################
# Would you like to cluster sequences into OTUs based on similarity?
CLUSTER_OTUS="YES"

# What method should be used to cluster OTUs?
#cluster_method="swarm" #[ swarm | vsearch | usearch ]
cluster_method="swarm"
# At what radius of similarity should OTUs be grouped into a cluster?
cluster_radius="1"

# Exclude from the analysis OTUs which are less abundant than what percent?
# Recommendation from Bokulich et al. (2013, Nature Methods): 0.005%
min_OTU_abun="0.005"
# TODO: incorporate into OTU filtering script

################################################################################
# FILTER CHIMERIC SEQUENCES (vsearch)
################################################################################
# Would you like to check for and filter out chimeras?
remove_chimeras="YES"

################################################################################
# TAXONOMIC ANNOTATION
################################################################################
## BLAST ##
# For more information on these parameters, type into a terminal window: blastn -help
# Specify the path to the BLAST database.
# Note this should be a path to any one of three files WITHOUT their extension *.nhr, *.nin, or *.nsq
#BLAST_DB='/MBON/blastdb/nr/nr'
#BLAST_DB='/MBON/blastdb/nt/nt'
#BLAST_DB='/MBON/blastdb/Tarav9/Tarav9'
#BLAST_DB='/atlasMBON/blastdb/nt/nt'
#BLAST_DB='/MBON/blastdb/greengenes/gg_13_5'
#BLAST_DB='/MBON/blastdb/greengenes/gg_13_5_with_header'
# new28s from Shannon Johnson, extracted from Genbank for locus 28S
#BLAST_DB='/MBON/mbonteam/MBARI/reiko/raw/new28S/28s_new'
#BLAST_DB='/MBON/blastdb/Silva/SILVA123_SSURef.ncbi.db'
BLAST_DB="$HOME_DIR/kevanMBARI_18S_test_data/Database/testdb.db"
# BLAST PARAMETERS
PERCENT_IDENTITY="97"
WORD_SIZE="20"
# EVALUE="1e-20"
#EVALUE="1e-10"
EVALUE="1e-5"
# number of matches recorded in the alignment:
MAXIMUM_MATCHES="400"
culling_limit="20"


################################################################################
## MEGAN ##
# For more information, see the manual provided with the software
# Specify the path to the MEGAN executable file you want to use.
# Note that in recent versions an executable was not provided; in that case, you need to reference like so: '/Applications/MEGAN/MEGAN.app/Contents/MacOS/JavaApplicationStub'
megan_exec='/usr/local/bin/MEGAN'

# What is the lowest taxonomic rank at which MEGAN should group OTUs?
COLLAPSE_RANK1="Family"
MINIMUM_SUPPORT="1"
MINIMUM_COMPLEXITY="0"
TOP_PERCENT="2"
MINIMUM_SUPPORT_PERCENT="0"
MINIMUM_SCORE="160"
LCA_PERCENT="90"
MAX_EXPECTED="1e-25"
# COLLAPSE_RANK1="Family"
# MINIMUM_SUPPORT="1"
# MINIMUM_COMPLEXITY="0"
# TOP_PERCENT="3"
# MINIMUM_SUPPORT_PERCENT="0"
# MINIMUM_SCORE="140"
# LCA_PERCENT="70"
 # MAX_EXPECTED="1e-25"

############## 
# Kevan Yamahara's additional parameters
# COLLAPSE_RANK1="Family"
# MINIMUM_SUPPORT="1"
# MINIMUM_COMPLEXITY="0"
# TOP_PERCENT="2"
# MINIMUM_SUPPORT_PERCENT="0"
# MINIMUM_SCORE="160"
# LCA_PERCENT=“90"

# Do you want to perform a secondary MEGAN analysis, collapsing at a different taxonomic level?
PERFORM_SECONDARY_MEGAN="YES"
COLLAPSE_RANK2="Genus"
COLLAPSE_RANK3="Phylum"


################################################################################
# REANALYSIS
################################################################################
# Would you like to pick up where a previous analysis left off?
# If reanalyzing existing demultiplexed data, point this variable to the directory storing the individual tag folders.
# EXISTING_DEMULTIPLEXED_DIR='/Users/threeprime/Documents/Data/IlluminaData/16S/20141020/Analysis_20141023_1328/demultiplexed'

# Have the reads already been paired?
ALREADY_PEARED="NO" # YES/NO
PEAR_OUTPUT='/Users/threeprime/Documents/Data/IlluminaData/12S/20140930/Analysis_20141030_2020/1_merged.assembled.fastq.gz'

# Have the merged reads been quality filtered?
ALREADY_FILTERED="NO" # [YES|NO]
FILTERED_OUTPUT='/Users/threeprime/Documents/Data/IlluminaData/12S/20140930/Analysis_20141030_2020/2_filtered_renamed.fasta'


################################################################################
# GENERAL SETTINGS
################################################################################
# Would you like to compress extraneous intermediate files once the analysis is finished? YES/NO
PERFORM_CLEANUP="YES"

# Is it ok to rename the sequences within a fasta file?
# This will only remove info about the machine; reads can still be traced back to origin in fastq.
# This will happen after the fastq has been converted to a fasta file at the quality filtering step.
RENAME_READS="YES"

# If you want to receive a text message when the pipeline finishes, input your number here:
NOTIFY_EMAIL="NO"
EMAIL_ADDRESS="mccann@mbari.org"




################################################################################
# GRAVEYARD
################################################################################
# What is the path to the reads?
# READ1='/Users/threeprime/Documents/GoogleDrive/Data_Illumina/16S/run_20150401/libraryA/lib1_R1.fastq.gz'
# READ2='/Users/threeprime/Documents/GoogleDrive/Data_Illumina/16S/run_20150401/libraryA/lib1_R2.fastq.gz'
