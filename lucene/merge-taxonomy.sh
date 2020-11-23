#!/usr/bin/env bash
# Author: Maria Prager

##################################################################################################################

# Merges taxonomy DwCAs using ALA TaxonomyBuilder (aka. Large Taxon Collider[LTC], java)
# Saves in/output, config & this file to run folder
# Outputs DwCA zip = input for ALA namindexer

##################################################################################################################

# Input folder names
in1="gtdb-small"
in2="gbif-small"

# Base dir
base=.

tmp=$base/tmp
# conf=$base/configs/sbdi-config.json
conf=$base/configs/sbdi-config.json

# Input
dir1=$base/sources/$in1; dir2=$base/sources/$in2

# Run
rdir=$base/runs/$(date +"%y%m%d-%H%M%S")-${in1}-${in2}

# Output
out=$rdir/"$in1-$in2"
mkdir $rdir $out

# Run Taxonomy Builder with config
java -cp ~/code/java/ala-name-matching-3.4-distribution/ala-name-matching-3.4.jar \
au.org.ala.names.index.TaxonomyBuilder -c $conf -w $tmp -o $out $dir1 $dir2\
> $rdir/run.log

# Copy script, data & config to run folder
cp -r $0 $dir1 $dir2 $conf $rdir
mv $tmp/taxonomy_report.csv $rdir


# Zip input (without hidden Mac files)
cd $out
zip -r ../gbif_gtdb.dwca.zip . -x ".*" -x "__MACOSX"

cd -

# rm -r $base/sources/$in1/*-sorted
rm -r $base/sources/$in2/*-sorted
