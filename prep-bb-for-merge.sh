#!/usr/bin/env bash
# Maria Prager

# GBIF-backbone subset: kingdom Archaea
# Replace with https://hosted-datasets.gbif.org/datasets/backbone/backbone-current.zip
# (but keep meta.xml)
indir=GBIF-BB-RL-190916-archea
outdir=lucene/sources/gbif-bb
mkdir $outdir

in_taxon=$indir'/Taxon.tsv'
out_taxon=$outdir'/taxon.tsv'

in_vern=$indir'/VernacularName.tsv'
out_vern=$outdir'/VernacularName.tsv'

in_dist=$indir'/Distribution.tsv'
out_dist=$outdir'/Distribution.tsv'

function prep_taxon {
    awk 'BEGIN {FS = OFS = "\t"}
    # Exclude rank cols, add code required by LTC
    FNR == 1 {$18="nomenclaturalCode"; {for (i=1; i<=18; i++) printf("%s%s", $i, i==18 ? ORS : OFS)}} \
    # Skip "?" scinames, replace sciname with canonical
    FNR > 1 {$18="dummyCode"; if ($6 !~ /^\?/) { if($8) $6 = $8; {for (i=1; i<=18; i++) printf("%s%s", $i, i==18 ? ORS : OFS)}}}' \
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
