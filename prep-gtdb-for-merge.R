################################################################################################
# prep-gtdb-for-merge.R
# Author: Maria Prager

# Reads GTDB taxonomy (see r-input/prep-gtdb-for-r.sh),
# For each row, moves from low to high rank and adds id, name, missing ancestors (as new rows)
# Parses rows again, and looks up id of closest parent to each row
# Outputs tsv-file to use in taxonomy-merge

################################################################################################
# EXTENSIONS

# install.packages("purrr")
# install.packages("dplyr")
# install.packages("tibble")
# install.packages("rstudioapi")
# install.packages("digest")
library(rstudioapi)
library(purrr)
library(tibble)
library(dplyr)
library(digest)

################################################################################################
# FUNCTIONS

# Read annotation file, if found
read.annot<- function(annot.file) {
  if (file.exists(annot.file)) {
    df <- read.delim(annot.file, header=T, sep='\t', stringsAsFactors=FALSE)
    return(df)
  } else { print(paste("Could not find file", annot.file, "in current directory", getwd()))}
}

# Rearrange and add cols to fit taxonomy builder
reformat.annot <- function(df) {
  # Replace missing values with 'NA'
  df[df == ''] <- NA
  # Cols to add (check later if all are needed, and if some should have data from db)
  cols <- c('parentNameUsageID', 'acceptedNameUsageID',	'originalNameUsageID',
            'scientificName',	'scientificNameAuthorship', 'taxonRank',	'taxonomicStatus')
  # Add cols
  df <- add_column(df, !!'taxonID' := NA, .before = 'datasetID')
  for (col in cols) {
    # !! := for string interpolation
    df <- add_column(df, !!col := NA, .before = 'kingdom')
  }
  df <- add_column(df, nomenclaturalCode = 'BC')
  # Add some data
  df$taxonomicStatus <- 'accepted'
  return(df)
}

# Get scientificName and rank using lowest partial rank
get.name.n.rank <- function(row, rpart) {
  if (rpart == 'infraspecificEpithet') {
    name <- paste(row[['genus']], row[['specificEpithet']], row[['infraspecificEpithet']])
    # Fix later
    rank <- 'unknown infraspecific'
  }
  else if (rpart == 'specificEpithet') {
    name <- paste(row[['genus']], row[['specificEpithet']]);
    rank <- 'species'
  }
  else {
    name <- row[[rpart]]
    rank <- rpart
  }
  name.rank <- c(name, rank)
  names(name.rank) <- c('name', 'rank')
  return(name.rank)
}

# Add id, name, rank
add.id.name.rank <- function(df, ranks) {
  idranks <- ranks[-c(8:10)]
  for(j in 1:nrow(df)) {
    row <- df[j,]
    # Step through ranks, from low to high
    name <- NA
    #if (!is.na(full.name)){print(paste(j))}
    for (i in rev(ranks)) {
      # If rank is empty, go to next
      if (is.na(row[[i]])) { next }
      name.rank <- get.name.n.rank(row, i)
      #taxonid <- sum.id(row$datasetID, row[idranks])
      taxonid <- sum.id('GTDB', row[idranks])
      # Erase rank from memory (to not affect next)
      row[[i]] <- NA
      # Use first non-empty rank field for focal taxon
      while (is.na(name)){
        name <- name.rank['name']
        rank <- name.rank['rank']
        # print(paste(j, name))
        if (taxonid %in% df$taxonID) {print(paste('row', j, 'is a duplicate. Fix, and try again')); next}
        df[j, 'taxonID'] <- taxonid
        df[j, 'taxonRank'] <- rank
        df[j, 'scientificName'] <- name
      }
    }
  }
  return(df)
}

# Add ancestors
add.ancestors <- function(df, ranks) {
  idranks <- ranks[-c(8:10)]
  for(j in 1:nrow(df)) {
    row <- df[j,]
    # Step through ranks, from low to high
    for (i in rev(ranks)) {
      # If rank is empty, go to next
      if (is.na(row[[i]])) { next }
      name.rank <- get.name.n.rank(row, i)
      # taxonid <- sum.id(row$datasetID, row[idranks])
      taxonid <- sum.id('GTDB', row[idranks])
      # If taxon exists, skip to next rank
      if (taxonid %in% df$taxonID) {row[[i]] <- NA; next}
      # Else add ancestor
      anc.name <- name.rank['name']
      anc.rank <- name.rank['rank']
      anc.row <- c(taxonid, row$datasetID, NA, NA, NA, anc.name, NA, anc.rank, 'accepted', (row[ranks]), NA)
      # Erase rank from memory (to not affect next)
      row[[i]] <- NA
      names(anc.row) <- colnames(df)
      df <- rbind(df, anc.row)
    }
  }
  return(df)
}

# Add closest parent id for each row, except for kingdom
add.parent.ids <- function(df, ranks) {
  for(j in 1:nrow(df)) {
    row <- df[j,]
    # Get lowest ancestor rank
    pp.rank <- rev(ranks)[get.nna.rank.no(row, ranks, 1)]
    # If no parent exists (i.e. rank = kingdom), skip to next taxon
    if (is.na(pp.rank)){ next }
    p.name <- get.name.n.rank(row, pp.rank)['name']
    p.rank <- get.name.n.rank(row, pp.rank)['rank']
    # # Look up id from name, and add
    p.id <- df[df['scientificName'] == p.name & df['taxonRank'] == p.rank
               & df['kingdom'] == row[['kingdom']], 'taxonID']
    df[j,'parentNameUsageID'] <- p.id
  }
  return(df)
}

# Get ordinal no. of first non-NA taxon rank
# Adjust 'generations' to get ancestor ranks, i.e. 1 -> closest parent
get.nna.rank.no <- function(row, ranks, generations = 0) {
  # Reverse, to start from low rank
  ranks <- rev(ranks)
  nona <- which(!is.na(row[ranks]))
  rank.no <- nona[1 + generations]
  return(rank.no)
}

# Get ancestors and their descendants, for single taxon name
filter.on.name <- function(df, name) {
  all = df[FALSE,]; anc = df[FALSE,]; chd = df[FALSE,]
  ids <- df$taxonID[df$scientificName == name]
  # If no match, return empty df
  if (length(ids) == 0) { print(paste(name, 'was not found.')); return(all)}
  ranks <- c('kingdom',  'phylum',  'class',  'order',  'family',  'genus', 'specificEpithet', 'infraspecificEpithet')
  for (i in ids) {
    rank <- df$taxonRank[df$taxonID == i]
    full.tax <- df[df$taxonID == i, ranks ]
    # (Name matching will include homonyms, if present, but not important here, I think)
    # Get ancestors (+ focal taxon) as names matching any ranks in taxonomy
    anc <- df[df$scientificName %in% full.tax,]
    # Get descendants, e.g. taxa that share name of current rank with focal taxon
    chd <- df[df[[rank]] == name & !is.na(df[[rank]]),]
    #& !is.na(df$rank),
    all <- rbind(all, anc, chd)
  }
  all <- all[!duplicated(all$taxonID),]
  return(all)
}

# Calculate taxonid as md5 of full taxonomy string (excl.NAs)
sum.id <- function(prefix, idranks){
  nona.str <- paste(idranks[!is.na(idranks)], collapse='')
  taxonid <- paste(prefix, digest( nona.str, algo="md5"), sep='-')
  return(taxonid)
}

################################################################################################
# MAIN

# Edit as needed
setwd(dirname(getActiveDocumentContext()$path))
annot.file <- 'r-input/gtdb-for-r-prep.tsv'
taxa <- c('Archaea', 'Bacteria')

ranks <- c('kingdom',  'phylum', 'class',  'order',  'family', 'genus', 'specificEpithet',
           'infraspecificEpithet')

df <- read.annot(annot.file)
df <- reformat.annot(df)
df <- add.id.name.rank(df, ranks)
df <- add.ancestors(df, ranks)
df <- add.parent.ids(df, ranks)
# Remove ranks (not accepted by LTC)
df = subset(df, select = - unlist(mget(ranks), use.names = FALSE))

# Save to tsvs
write.table(df, file = "lucene/sources/gtdb/taxon.tsv", sep='\t', row.names = F, na = '', quote = FALSE)
