#!/usr/bin/env bash
# Maria Prager

##################################################################################################################

# Prepares GTDB taxonomy file (Bacteria + Archae) for further manip in R
# Outputs tsv
# ToDo: Include GTDB-NCBI synonyms

##################################################################################################################

# Edit as needed
indir=GTDB-RL-r95
outdir=r-input

function prep_file {
    # Removes rank prefix & duplicates, split sp -> genus + sp-epith, add hdr & datasetID
    sed $'s/\t/;/g' $1 | awk -v hdr=$4 -v fname=$2 'BEGIN{FS=";"; print hdr}
    {gsub(/(d|p|c|o|f|g|s)_+/,"",$0); split($8,parts," "); $9=parts[2]}
    {if (!seen[$8 $9]++) print "GTDB_"fname, $2, $3, $4, $5, $6, $7, $9}' \
    OFS="\t" > $3
}
# Add header to final output
hdr="datasetID\tkingdom\tphylum\tclass\torder\tfamily\tgenus\tspecificEpithet\tinfraspecificEpithet"
echo $hdr > $outdir'/gtdb-for-r-prep.tsv'
for infile in $(ls $indir/*.tsv);
    do
        name=$(basename -s .tsv $infile)
        outfile=$outdir/$name'.tsv'
        prep_file $infile $name $outfile $hdr
        # Append content to final output
        sed 1d $outfile >> $outdir'/gtdb-for-r-prep.tsv'
        rm $outfile
    done
