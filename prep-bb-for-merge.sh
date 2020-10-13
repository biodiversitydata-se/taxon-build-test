#!/usr/bin/env bash
# Maria Prager

# GBIF-backbone subset: kingdom Archaea
# Replace with https://hosted-datasets.gbif.org/datasets/backbone/backbone-current.zip
# (but keep meta.xml)
indir=GBIF-BB-RL-190916-archea
outdir=lucene/sources/gbif-bb

in_taxon=$indir'/Taxon.tsv'
out_taxon=$outdir'/taxon.tsv'

in_vern=$indir'/VernacularName.tsv'
out_vern=$outdir'/VernacularName.tsv'

in_dist=$indir'/Distribution.tsv'
out_dist=$outdir'/Distribution.tsv'

function prep_taxon {
    awk 'BEGIN{FS = OFS = "\t"}
    # Add some headers
    FNR == 1 {print $0 OFS "nomenclaturalCode" OFS "tempAuthor"} \
    # Skip "?" scinames, replace sciname with canonical, if provided, and temp. replace authorship with "x"
    FNR > 1 { if ($6 !~ /^\?/) { if($8)$6 = $8; $25 = $7; $7 = "x"; print }}' \
    $1 > $2
}

function prep_ext {
    awk 'BEGIN{ FS = OFS = "\t" }
    # Add empty required field
    FNR == 1 { print $0 OFS "datasetID" } \
    FNR > 1 { print $0 OFS "" }' \
    $1 > $2
}
# Edit some files
prep_taxon $in_taxon $out_taxon
prep_ext $in_vern $out_vern
prep_ext $in_dist $out_dist
# Copy remaining files
for f in $(ls $indir); do
    if [ ! -f "$outdir/$f" ]; then
        cp "$indir/$f" $outdir
    fi
done
