#!/usr/bin/env bash
# Author: Maria Prager

##################################################################################################################

# Merges taxonomy DwCAs using ALA TaxonomyBuilder (java)
# Saves in/output & this file to run folder
# Outputs DwCA zip (called dyntaxa for now) = input for ALA namindexer
# ToDo: Compose config file

##################################################################################################################

# Input folder names
in1="gtdb-small"
in2="gbif-small"

# Base dir
base=.

tmp=$base/tmp
conf=$base/configs/sbdi-config.json

# Input
dir1=$base/sources/$in1; dir2=$base/sources/$in2

# Run
rdir=$base/runs/$(date +"%y%m%d-%H%M%S")-${in1}-${in2}
# Output
out=$rdir/"$in1-$in2"
mkdir $rdir $out

# # Run Taxonomy Builder
# java -cp ~/code/java/ala-name-matching-3.4-distribution/ala-name-matching-3.4.jar \
# au.org.ala.names.index.TaxonomyBuilder -w $tmp -o $out $dir1 $dir2\
# > $rdir/run.log

# Run Taxonomy Builder with config
java -cp ~/code/java/ala-name-matching-3.4-distribution/ala-name-matching-3.4.jar \
au.org.ala.names.index.TaxonomyBuilder -c $conf -w $tmp -o $out $dir1 $dir2\
> $rdir/run.log



# Copy indata to run folder
cp -r $dir1 $dir2 $rdir
# Add this script
cp $0 $rdir

cd $out

# Zip input (without hidden Mac files)
zip -r ../gbif_gtdb.dwca.zip . -x ".*" -x "__MACOSX"
