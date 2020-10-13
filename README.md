# taxon-build-test
Scripts for running and preparing input to the [ALA Taxonomy builder and nameindexer](https://github.com/AtlasOfLivingAustralia/documentation/wiki/A-Guide-to-Getting-Names-into-the-ALA). These tools may be used to merge the [GBIF taxonomy backbone](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c) with the [Genome Taxonomy DataBase (GTDB) taxonomy](https://gtdb.ecogenomic.org/about), to improve taxonomic coverage of prokaryotes in the BioAtlas. 
### Data input
1. GTDB-RL-r95: GTDB release r95 data
2. GBIF-BB-190916-archaea: Subset of the GBIF backbone, which should be replaced with the [complete backbone](https://hosted-datasets.gbif.org/datasets/backbone/backbone-current.zip)
### Run like this
1. Get ALA Taxonomy builder and nameindexer.
```bash
wget https://nexus.ala.org.au/service/local/repositories/releases/content/au/org/ala/ala-name-matching/3.4/ala-name-matching-3.4.jar
```
2. Preprocess GBIF backbone. Will save processed folder to *taxon-build-test/lucene/sources/*.
```bash
sh prep-bb-for-merge.sh
```
3. Preprocess GTDB files. Step 1 (bash), will save processed file to *r-input*.
```bash
sh prep-gtdb-for-r.sh
```
4. Preprocess GTDB files. Step 2 (R), will save processed file to *taxon-build-test/lucene/sources/*.
```
prep-gtdb-for-merge.R
```
5. Go to lucene folder and run taxonomy builder. Will save input, script and output to folder under *taxon-build-test/lucene/runs/*.
```bash
sh merge-taxonomy.sh
```
### NOTE
1. Could not get taxonomy builder to deal with scientificNames that start with '?', so have excluded those from GBIF-bb.
2. As the taxonomy builder seemed to create duplicates whenever GTDB and GBIF contained taxa with identical names but different authors (GTDB does not have any), I temporarily set both author (scientificNameAuthorship) columns to 'x', and then copy back data from GBIF, after the merge. Probably not ideal.
3. I have not used any configuration file for the builder.

