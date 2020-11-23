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
5. Go to lucene folder and run taxonomy builder. Will save input, script, output and log to folder under *taxon-build-test/lucene/runs/*.
```bash
sh merge-taxonomy.sh
```
## Taxonomy implementation in the BioAtlas
The steps below describe how to implement the merged taxonomy in a test version of the BioAtlas, and assumes that scp & ssh connection options (host, user, RSA key file) are specified in a *.ssh/config file*, allowing alias usage (*cloud*). NOTE that I use the *dyntaxa* label and *dyntaxa-index* directory for convenience only.

1. Copy taxonomy-dwca (and if needed, the java tool nameindexer.zip) to server
```console
scp ~/data/lucene/runs/xxx/dyntaxa.dwca.zip cloud:repos/ala-docker/dyntaxa-index
```
2. Login to cloud server, and navigate to ala-docker dir
```console
ssh cloud
cd /repos/ala-docker
```
3. Build nameindex image \[*name:tag* - edit as needed\], using the namindexer tool in the *dyntaxa-index* directory.
```console
docker build --no-cache -t bioatlas/ala-dyntaxaindex:xxx dyntaxa-index
```
4. Test search index (by searching for taxon zzz)
```console
docker run --rm -it bioatlas/ala-dyntaxaindex:xxx nameindexer -testSearch zzz
```
&nbsp;&nbsp;&nbsp;&nbsp; Should output something similar to:
```console
...
Classification: "null",Bacteria,Acidobacteriota,Acidobacteriae,Acidobacteriales,Acidobacteriaceae,Edaphobacter
Scientific name: zzz
...
Match type: exactMatch
```
5. Setup nameindex service to start from newly created index image
```console
nano docker-compose.yml
```
&nbsp;&nbsp;&nbsp;&nbsp; Use *Ctrl+w* to search for e.g. 'dynt'. Comment out current image and add new image, like so:
```console
nameindex:
#image: bioatlas/ala-nameindex:v0.4
#image: bioatlas/ala-dyntaxaindex:v0.4
image: bioatlas/ala-dyntaxaindex:xxx
command: /bin/ash
container_name: nameindex
...
```
&nbsp;&nbsp;&nbsp;&nbsp; Use *Ctrl+x* to save

6. Clean-up data volumes (will remove indices, and all data from ingested datasets)
```console
docker-compose stop nameindex biocachebackend biocacheservice specieslists
docker rm -vf solr cassandradb nameindex biocachebackend biocacheservice specieslists
docker volume rm ala-docker_data_solr ala-docker_db_data_cassandra ala-docker_data_nameindex
```
7. Restart services (will create new nameindex service, as configurated in *docker-compose.yml*)
```console
docker-compose up -d
docker-compose restart webserver
```
8. Add a new data resource (at least add a name), and upload your occurrence dwca.zip in Collectory

9. Map records against nameindex (will update the Solr index for Occurrence search \[core: biocache\])
```console
docker-compose run --rm biocachebackend biocache

# List available data resources
list

# Fetch DwCA from collectory and write to cassandra database
biocache> load drX

# Match records against nameindex, and update in cassandra
biocache> process -dr drX

# Write occurrence records from cassandra to SOLR index -> generates the ALA-hub Occurrence search index
biocache> index -dr drX

# Quit
exit
```
10. Restart services
```console
docker-compose restart biocacheservice biocachehub
```

11. Prepare files for creating Solr index for Taxonomic search  \[cores: bie-offline / bie\]
```console
# Move old taxonomy dwca to backup folder
docker exec -it bieindex bash
mv /data/bie/import/dwc-a /data/bie/import/dwca-maria-XXXXXX
exit

# Unzip new taxonomy dwca
cd dyntaxa-index/
mkdir dwc-a
unzip dyntaxa.dwca.zip -d dwc-a

# Copy into running bieindex container
docker cp dwc-a bieindex:/data/bie/import/
```

*Some background: Solr core = running instance of a Lucene index, needed to perform indexing. The taxonomic index in BAS has two alternative cores, with the same schema (structure): bie and bie-offline. Swapping cores means to swap file pointers (inc. filename) between the cores. The point of this is to make it possible to perform the resource intensive and long process of taxonomy index generation offline (to produce bie-offline), so that it does not block the search functionality, before swapping it with the bie.*

12. Import taxonomy to bie-offline index
<br>Go to Admin | BIE Web services
<br>Click *DwCA Import - Import taxon data in Darwin Core Archive form*
<br>Check *Clear existing taxonomic data*, to clear up old stuff if any
<br>Click */data/bie/import/dwc-a Import DwCA*

13. Swap cores
<br>In SOLR admin, click *Core Admin* | *Swap*
<br>Make sure it reads *this: bie andand: bie-offline*
<br>Click *Swap Cores*

14. If needed, restart services
```console
make up
docker-compose restart webserver
```

### Issues & ToDo
1. Could not get taxonomy builder to deal with scientificNames that start with '?', so have excluded those from GBIF-bb.
2. Inspect taxonomy_report.se
3. Fine-tune SBDI-specific config
4. Nomencaltural code 'BC' now added to all GBIF bb rows, which will not work for full GBIF bb merge.
