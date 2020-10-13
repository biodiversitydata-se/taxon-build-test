#!/usr/bin/env bash
# Author: Maria Prager

##################################################################################################################

# Merges taxonomy DwCAs using ALA TaxonomyBuilder (java)
# Saves in/output & this file to run folder
# Restores tax. author info from GBIF backbone (temp. replaced with 'x' to match GTDB/Silva)
# Outputs DwCA zip (called dyntaxa for now) = input for ALA namindexer
# ToDo: Compose config file

##################################################################################################################

# Input folder names
in1="gtdb"
in2="gbif-bb"

# Input
dir1=sources/$in1; dir2=sources/$in2
# Run
rdir=runs/$(date +"%y%m%d-%H%M%S")-${in1}-${in2}
# Output
out=$rdir/"$in1-$in2"
mkdir $rdir $out

# Run Taxonomy Builder
java -cp ~/code/java/ala-name-matching-3.4-distribution/ala-name-matching-3.4.jar \
au.org.ala.names.index.TaxonomyBuilder -w tmp -o $out $dir1 $dir2\
> $rdir/run.log

# Copy indata to run folder
cp -r $dir1 $dir2 $rdir
# Add this script
cp $0 $rdir

cd $out

# Run if you have manipulated scientificNameAuthorship field:
# Restore author in taxon.txt
awk -F "\t" 'NR == 1 {for(i=1; i<=NF; i++) {f[$i]=i}}
NR > 1 { $(f["scientificNameAuthorship"]) = $(f["tempAuthor"])}
{print}' OFS="\t" taxon.txt > tax.tmp && mv tax.tmp taxon.txt
# Lokup author in taxonvariant file from taxon file
# NR row no (counted over both files), FNR row no in current file
awk -F"\t" '\
NR==1 {for(i=1; i<=NF; i++){f1[$i]=i}}
NR>1 && FNR==1 {for(j=1; j<=NF; j++){f2[$j]=j}}
NR==FNR{var[$1]=$(f1["scientificNameAuthorship"]); next} \
{$(f2["scientificNameAuthorship"])=var[$1]} {print}' \
OFS="\t" taxon.txt taxonvariant.txt > var.tmp && mv var.tmp taxonvariant.txt

# Zip input (without hidden Mac files)
zip -r ../dyntaxa.dwca.zip . -x ".*" -x "__MACOSX"
