# install.packages("taxize")

# TODO allow collapse at specified rank (e.g. family) in function LCA
library(taxize)

# TODO take command line argument
# blast_results_file_path  <- "/Users/threeprime/Documents/GoogleDrive/Kelly_Lab/Projects/Lemonade/Data/blast_20151125_1530/blast_results_all.txt"
blast_results <- read.table(
	file = blast_results_file_path, 
	sep = "\t", 
	stringsAsFactors = FALSE, 
	quote = NULL, 
	comment = ''
	)


# TODO remove this option
# set up the column names by hand...
query_col=1
evalue_col=11
bitscore_col=12
title_col=13
gi_col=2
# taxid_col="taxid1_all" # change this to a column number if it was returned in the blast output

# ...or automatically
# table columns order: 
output_format <- "6 qseqid sallseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore staxids stitle"
# TODO just apply these as column names to the dataframe

if( strsplit(output_format, " ")[[1]][1] != 6 ){
	stop("the output format string must begin with a 6 (indicating blast tabular output)")
}
output_columns <- strsplit(output_format, " ")[[1]][-1] # [-1] removes the first value (integer) used to tell blastn which output (should always be 6)
colnames(blast_results) <- output_columns
query_col <- which(output_columns == "qseqid")
evalue_col <- which(output_columns == "evalue")
bitscore_col <- which(output_columns == "bitscore")
title_col <- which(output_columns == "stitle")
gi_col <- which(output_columns == "sallseqid")
taxid_col <- which(output_columns == "staxids") # if this doesn't exist we will create it

# This is required to parse sequence abundance/count data from sequence headers
abundance_prefix <- ";size="


#----------------------------------------------------------------------------------------
# Define some functions
#----------------------------------------------------------------------------------------
next_best_taxon <- function(x){
	paste("below-",
		tail(x[,"rank"][!duplicated(x[,"rank"])], n = 1
		), sep = "")
}
lapply(class_norank, next_best_taxon)

LCA <- function(taxid_vec, class_list)
{
	# This function takes a (character) vector of NCBI taxids, 
	# and a list of classification hierarchies (from taxize)
	# outputs the name, rank, and taxid of the (taxonomic) lowest common ancestor
	if(class(taxid_vec) != "character"){
		taxid_vec <- as.character(taxid_vec)
	}
	relevant_class <- class_list[taxid_vec]
	# remove unclassified sequences
	# NOTE THIS IN THE METHODS "We ignored hits belonging to 'unclassified sequences'"
	classified_sequences <- sapply(relevant_class, function(x) x[1,1] != "unclassified sequences")
	relevant_class <- relevant_class[classified_sequences]
	LCA_row <- length(Reduce(intersect, lapply(relevant_class, "[[", 1)))
	# TODO add taxonomic rank retrieval -- e.g. c("class", "family")
	LCA <- relevant_class[[1]][LCA_row,]
	if(LCA[1,"rank"] == "no rank"){
		LCA[1,"rank"] <- next_best_taxon(relevant_class[[1]][1:LCA_row,]) # as.character(LCA_row)
	}
	return(LCA)
}
# LCA(c("6551", "941636"), classifications)
# LCA(names(classifications[1:4]), classifications)



hit_summary <- function(x, class_list)
{
	# this function takes a dataframe, presumably the tabular output of blastn
	# calculates the best (lowest) e-value,
	# and returns a dataframe with a single row resolving taxonomic ties
	beste <- min(x[ , evalue_col])
	beste_rows <- x[ , evalue_col] == beste
	LCA_all <- LCA(x[ , taxid_col], class_list)
	LCA_beste <- LCA(x[beste_rows , taxid_col], class_list)
	
	query_taxonomy <- data.frame(
		query_seq = unique(x[ , query_col]), 
		Nhits = nrow(x), 
		N_taxid_all = length(unique(x[ , taxid_col])), 
		beste = beste, 
		Nhits_beste = sum(beste_rows), 
		N_taxid_beste = length(unique(x[beste_rows , taxid_col])), 
		LCA_name_all = LCA_all[, "name"], 
		LCA_rank_all = LCA_all[, "rank"], 
		LCA_id_all = LCA_all[, "id"], 
		LCA_name_beste = LCA_beste[, "name"], 
		LCA_rank_beste = LCA_beste[, "rank"], 
		LCA_id_beste = LCA_beste[, "id"]
	)
	return(query_taxonomy)
}
# hit_summary(blast_queries[[1]], classifications)

# Functions now in taxize:
lowest_common <- function(...){
  UseMethod("lowest_common")
}

lowest_common.default <- function(ids, db = NULL, class_list = NULL, ...) {
  if(!is.list(class_list)){
    class_list <- classification(ids, db = db, ...)
  }
  lc_helper(ids, class_list, ...)
}

lowest_common.uid <- function(ids, class_list = NULL, ...) {
  if(!is.list(class_list)){
    class_list <- classification(ids, db = "uid",  ...)
  }
  lc_helper(ids, class_list, ...)
}

lowest_common.tsn <- function(ids, class_list = NULL, ...) {
  if(!is.list(class_list)){
    class_list <- classification(ids, db = "itis", ...)
  }
  lc_helper(ids, class_list, ...)
}

lowest_common.gbifid <- function(ids, class_list = NULL, ...) {
  if(!is.list(class_list)){
    class_list <- classification(ids, db = "gbif", ...)
  }
  lc_helper(ids, class_list, ...)
}

lc_helper <- function(ids, class_list, low_rank = NULL) {
  idsc <- class_list[ids]
  cseq <- vapply(idsc, function(x) x[1, 1] != "unclassified sequences", logical(1))
  idsc <- idsc[cseq]
  if(is.null(low_rank)){
    x_row <- length(Reduce(intersect, lapply(idsc, "[[", 1)))
    x <- idsc[[1]][x_row, ]
    if (x[1, "rank"] == "no rank") {
      x[1, "rank"] <- next_best_taxon(idsc[[1]][1:x_row, ])
    }
    return(x)
  } else {
    # could test, warn/error that supplied rank is valid
    low_rank_names <- as.character(unique(unlist(lapply(idsc, function(x) x$name[which(x$rank == low_rank)]))))
    if(length(low_rank_names) == 1){
      return(low_rank_names)
    } else {
      return(NA)
    }
  }
}


#----------------------------------------------------------------------------------------
# Calculate hits per query
#----------------------------------------------------------------------------------------
# TODO this should work at any stage, but consider thinking about where to put it
gi_list <- sapply(blast_results[,gi_col], function(x) strsplit(x, split = ";", fixed = TRUE))
subhit_gi <- as.numeric(sapply(gi_list, length))
hits_per_query <- sapply(split(subhit_gi, blast_results[,query_col]), sum)

#----------------------------------------------------------------------------------------
# Split subhits into hits
#----------------------------------------------------------------------------------------
# Sequences in NCBI (GenBank) that are completely identical will be returned as a single hit
# These will each have unique GI numbers; they may or may not be from multiple taxa (thus multiple taxids)

# IF TAXIDS NOT IN DATAFRAME, DO THIS:
if( length(taxid_col) == 0 ){
	multi_gi <- grep(pattern = ";", x = blast_results[, gi_col], fixed = TRUE)
	if(length(multi_gi) > 0){
		gi_list <- sapply(blast_results[,gi_col], function(x) strsplit(x, split = ";", fixed = TRUE))
		subhit_gi <- as.numeric(sapply(gi_list, length))
		blast_results <- blast_results[rep(1:nrow(blast_results), times = subhit_gi),]
		blast_results[,gi_col] <- unlist(gi_list)
	}

# IF TAXIDS ARE IN THE DATAFRAME, IGNORE GI AND DO THIS:
} else if( length(taxid_col) == 1 ){
	multi_taxid <- grep(pattern = ";", x = blast_results[, taxid_col], fixed = TRUE)
	if(length(multi_taxid) > 0){
		taxid_list <- sapply(blast_results[,taxid_col], function(x) strsplit(x, split = ";", fixed = TRUE))
		subhit_taxid <- as.numeric(sapply(taxid_list, length))
		blast_results <- blast_results[rep(1:nrow(blast_results), times = subhit_taxid),]
		blast_results[,taxid_col] <- unlist(taxid_list)
	}
} else {
	warn('hmm... something seems fishy. Check the "staxids" column')
}


# N_subhits <- cbind(
# subhit_gi = as.numeric(sapply(sapply(blast_results[,gi_col], function(x) strsplit(x, split = ";", fixed = TRUE)), length)),
# subhit_taxid = as.numeric(sapply(sapply(blast_results[,taxid_col], function(x) strsplit(x, split = ";", fixed = TRUE)), length))
# )



#----------------------------------------------------------------------------------------
# Extract GI numbers
#----------------------------------------------------------------------------------------
# There can be multiple gi numbers associated with a single hit; for now just grab the first.
# I don't know exactly why this is, but more info can be found here: 
# http://www.ncbi.nlm.nih.gov/genbank/sequenceids/
gi1_all <- do.call(c, lapply(strsplit(blast_results[,gi_col], split = "|", fixed = TRUE), "[", 2))
blast_results <- cbind.data.frame(blast_results, gi1_all, stringsAsFactors = FALSE)
gi_unique <- as.character(unique(gi1_all))



time_start <- Sys.time()
#----------------------------------------------------------------------------------------
# Get taxon ID of unique gi numbers
#----------------------------------------------------------------------------------------
# check for the 'staxids' column in the blast table
# if it isn't there, get it from NCBI using taxize::genbank2uid
# 1.771811 hours for length(least_common_ancestor) == 1601, mostly over network getting taxid
# This could be avoided by having the taxid given back by blastn, or doing this in python (15 minutes)
if( length(taxid_col) == 0 ){
	taxids <- vector(mode = "character")
	for(i in 1:length(gi_unique)){
		taxids[i] <- genbank2uid(id = gi_unique[i])[1]
	}
	
	gi_taxid <- data.frame(
		gi = gi_unique, 
		taxid = taxids, 
		stringsAsFactors = FALSE
	)
	# put taxon ids onto blast results
	taxid1_all <- gi_taxid$taxid[match(gi1_all, gi_taxid$gi)]
	blast_results <- cbind.data.frame(blast_results, taxid1_all, stringsAsFactors = FALSE)


} else {
	# There can be multiple taxid numbers associated with a single hit; for now just grab the first.
	# taxid1_all <- do.call(c, lapply(strsplit(blast_results[,taxid_col], split = ";", fixed = TRUE), "[", 1)) # range check 71735:71749
	# blast_results <- cbind.data.frame(blast_results, taxid1_all, stringsAsFactors = FALSE)
	# gi_taxid <- data.frame(
		# gi = gi_unique, 
		# taxid = blast_results[,"taxid1_all"][match(gi_unique, blast_results[,"gi1_all"])],
		# stringsAsFactors = FALSE
	# )

}

# taxid_col <- "taxid1_all"

# hits for which the taxon id was unresolved (i.e. "NA") will be problematic, so remove them
blast_results_taxid_NA <- blast_results[is.na(blast_results[, taxid_col]),]
blast_results <- blast_results[!is.na(blast_results[, taxid_col]),]

blast_queries <- split(blast_results, blast_results[, query_col])

	
beste_table <- do.call(
		rbind, 
		lapply(
			X = blast_queries,
			FUN = function(x)
			{
				x[x[ , evalue_col] == min(x[ , evalue_col]),]
			}
		)
	)
rownames(beste_table) <- NULL

# write.table(
	# x = gi_taxid, 
	# file = "gi_taxid_20160202.txt", 
	# quote = FALSE, 
	# row.names = FALSE
# )
# gi_taxid <- read.table(file = "gi_taxid_20160202.txt", header = TRUE, colClasses = "character")


#----------------------------------------------------------------------------------------
# Get taxonomic hierarchy from taxon ids
#----------------------------------------------------------------------------------------
# requires network connection; could take some time
if( length(taxid_col) == 0 ){
	taxid_uniq <- unique(gi_taxid$taxid)
} else{
	taxid_uniq <- unique(blast_results[,taxid_col])
}
classifications <- classification(x = taxid_uniq, db = "ncbi")
# save(classifications, file = "classifications20160202.RData")


#----------------------------------------------------------------------------------------
# make dataframe of hit summaries for each query sequence
#----------------------------------------------------------------------------------------
hit_summaries <- lapply(blast_queries, hit_summary, class_list = classifications)
# alt: library(data.table); rbindlist(hit_summaries)
names(hit_summaries) <- NULL
query_hit_LCA <- do.call(rbind, hit_summaries)
head(query_hit_LCA)

taxid_by_qid_all <- split(blast_results[,taxid_col], blast_results[,query_col])
taxid_by_qid_beste <- split(beste_table[,taxid_col], beste_table[,query_col])

class_all <-sapply(taxid_by_qid_all, lowest_common, class_list = classifications, low_rank = 'class')
order_all <- sapply(taxid_by_qid_all, lowest_common, class_list = classifications, low_rank = 'order')
family_all <- sapply(taxid_by_qid_all, lowest_common, class_list = classifications, low_rank = 'family')

class_beste <-sapply(taxid_by_qid_beste, lowest_common, class_list = classifications, low_rank = 'class')
order_beste <- sapply(taxid_by_qid_beste, lowest_common, class_list = classifications, low_rank = 'order')
family_beste <- sapply(taxid_by_qid_beste, lowest_common, class_list = classifications, low_rank = 'family')

query_hit_LCA <- cbind.data.frame(
	query_hit_LCA, class_all, order_all, family_all, class_beste, order_beste, family_beste, 
	stringsAsFactors = FALSE
	)

# parse "size=" abundance data
# copy this to main blast_results?
if(grepl(abundance_prefix, query_hit_LCA[1, "query_seq"], fixed = TRUE)){
	query_abundance <- as.numeric(sapply(strsplit(as.character(query_hit_LCA[, "query_seq"]), split = abundance_prefix), "[[", 2))
	query_hit_LCA <- cbind.data.frame(query_hit_LCA, query_abundance)
}

counts_by_taxa <- sapply(split(query_hit_LCA[,"query_abundance"], query_hit_LCA[,"LCA_name_beste"]), sum)
top50 <- sort(counts_by_taxa, decreasing = TRUE)[1:50]
top50 <- top50[!is.na(top50)]
write.csv(x = query_hit_LCA, file = "query_hit_LCA.csv", quote = TRUE, row.names = FALSE)



# TODO clean up plotting
pdf(file = "most_abundant_taxa.pdf")
par(mar = c(4, 12, 1, 1))
barplot(
	top50, 
	horiz = TRUE, 
	las = 1, 
	xlab = "number of reads"
)
# axis(2, at = seq_along(top50), labels = names(top50), cex.axis = 0.5, las = 1)

dev.off()

#----------------------------------------------------------------------------------------
# Get names of taxonomic ranks (e.g. "kingdom", "subphylum", etc)
#----------------------------------------------------------------------------------------
ranknames <- getranknames()
unique_ranks <- sort(as.numeric(unique(ranknames[,"rankid"])))
all_ranks <- tolower(ranknames[match(as.character(unique_ranks), ranknames[,"rankid"]),"rankname"]) # c(, "no rank")
all_ranks_full <- c(rbind(all_ranks, paste("below-", all_ranks, sep = "")))


#----------------------------------------------------------------------------------------
# group hits by the best (lowest) taxonomic level
#----------------------------------------------------------------------------------------
# TODO calculate on size annotation
rank_counts <- table(rep(query_hit_LCA[,"LCA_rank_all"], times = query_abundance))[all_ranks_full]
rank_counts <- rank_counts[!is.na(rank_counts)]
total_sequences <- sum(rank_counts)
rank_counts_prop <- rank_counts/total_sequences

pdf(file = "hits_by_best_tax.pdf")
par(mar = c(4, 9, 1, 1))
barplot(
	rank_counts_prop, 
	horiz = TRUE, 
	las = 1, 
	xlab = paste("proportion of", total_sequences, "sequences")
)
dev.off()

#----------------------------------------------------------------------------------------
# group evalues by best taxonomic level
#----------------------------------------------------------------------------------------
beste_by_rank <- split(query_hit_LCA[,"beste"], query_hit_LCA[, "LCA_rank_all"])[all_ranks_full]
beste_by_rank_ordered <- beste_by_rank[sapply(beste_by_rank, function(x) !is.null(x))]
beste_by_rank_log <- lapply(beste_by_rank_ordered, log)

pdf(file = "evalue_by_best_tax.pdf")
par(mar = c(4, 9, 1, 1))
boxplot(
	beste_by_rank_log, 
	horizontal = TRUE, 
	las = 1, 
	xlab = "log(e-value) of best hit"
)
dev.off()


#****************************************************************************************
# Everything below this is a mess and needs to be cleaned up 
#****************************************************************************************
besthits <- function(x){
	x[x[, evalue_col] == min(x[, evalue_col]),]
}

##############################################################################################
# Holy macaroni, that's it! Come back and clean this up!
least_common_ancestor <- list()
for(i in 1:length(blast_queries)){
	besthit_gis <- as.character(besthits(blast_queries[[i]])[,"gi1_all"])
	besthit_taxids <- unique(gi_taxid[match(besthit_gis, gi_taxid[,"gi"]),"taxid"])
	least_common_ancestor[[i]] <- Reduce(intersect, names_only[besthit_taxids])
}
# Holy macaroni, that's it! Come back and clean this up!
##############################################################################################
time_end <- Sys.time()
# 1.771811 hours for length(least_common_ancestor) == 1601, mostly over network getting taxid

# extract only the rows corresponding to the lowest e-value (best hit)
blast_queries_best <- lapply(X = blast_queries, FUN = besthits)

# assess the number of taxonomic ties per e-value
blast_queries[[1]][ , taxid_col]

taxid_per_query <- split(blast_results[ , taxid_col], blast_results[, query_col])
taxid_per_query_best <- lapply(blast_queries_best, "[[", taxid_col)

taxon_hit_index <- function(x)
{
	# this function takes a character vector of taxa (names or id numbers)
	# and calculates the ratio of unique taxa per hit
	# varies between 0 and 1, lower is better.
	length(unique(x))/length(x)
}

taxon_hit_index(blast_queries[[1]][ , taxid_col])

taxon_hit_all <- sapply(X = taxid_per_query, FUN = taxon_hit_index)
taxon_hit_best <- sapply(X = taxid_per_query_best, FUN = taxon_hit_index)

hit_index_evalue <- list(taxon_hit_all, taxon_hit_best)

pdf(file = "tax_hit_index.pdf")
boxplot(
	x = hit_index_evalue, 
	ylab = "N taxa / N hits", 
	names = c("all e-values", "only best e-value")
)
stripchart(
	x = hit_index_evalue, 
	vertical = TRUE, 
	add = TRUE, 
	method = "jitter",  
	jitter = 0.2, 
	pch = 19, 
	col = hsv(h = 0, s = 1, v = 1, alpha = 0.2), 
	cex = 0.8
)
dev.off()
for(i in 1:length(hit_index_evalue)){
	points(
		x = jitter(rep(i, length(hit_index_evalue[[i]])), factor = 7), 
		y = hit_index_evalue[[i]], 
		pch = 19, 
		col = hsv(h = 0, s = 0, v = 0, alpha = 0.5), 
		cex = 0.8
	)
}

query_seq <- unique(blast_results[ , query_col ])
# or if using factor this might work levels(blast_results[ , query_col ])

# what is the lowest evalue or highest bitscore per query sequence
best_evalue <- lapply(split(blast_results[ , evalue_col ], blast_results[,query_col]), min)
best_bitscore <- lapply(split(blast_results[ , bitscore_col ], blast_results[,query_col]), max)


max(blast_results[,evalue_col])


best_tax <- function(x){
  best_matches <- which(x[ , bitscore_col] == max(x[ , bitscore_col]))
  return(x[best_matches , title_col])
}

best_gi <- function(x, gi_col = 2){
  best_matches <- which(x[ , bitscore_col] == max(x[ , bitscore_col]))
  return(x[best_matches , gi_col])
}

stitles <- lapply(
              split(
                  blast_results, 
                  blast_results[ , query_col] 
                ), 
              best_tax
              )


#

splitter <- function(x){
  Reduce(paste, strsplit(x, split = " ")[[1]][1:2])
}
splitter(stitles[[2]])


Reduce(paste, strsplit(x, split = " ")[[1]][1:2])

# THIS WORKS!!!

do.call(rbind, lapply(stitles[[2]], function(x) Reduce(paste, strsplit(x, split = " ")[[1]][1:2])))
# THIS WORKS!!!

lapply(stitles[[2]], splitter)


unique(as.vector(do.call(rbind, lapply(stitles[[2]], function(x) Reduce(paste, strsplit(x, split = " ")[[1]][1:2])))))
table(as.vector(do.call(rbind, lapply(stitles[[2]], function(x) Reduce(paste, strsplit(x, split = " ")[[1]][1:2])))))

# Holy shit, finally.
taxa_hits <- lapply(
  stitles,
  function(x){
    as.vector(
      do.call(
        rbind, 
        lapply(
          x, function(x){
              Reduce(paste, strsplit(x, split = " ")[[1]][1:2])
            }
          )
        )
    )
  }
)

taxa_unique <- sapply(taxa_hits, unique)
sapply(taxa_hits, table)


# Put this on hold until PICKUP

#############################################
# as one function
tax_list <- function(x){
  best_matches <- which(x[ , bitscore_col] == max(x[ , bitscore_col]))
  titles_sub <- x[best_matches , title_col]
  
}
##############################################





# PICKUP
classification("Quietula y-cauda", db = "itis")



# TAXIZE
########
taxa_unique

# this requires a network connection, and could take a while
tax_hier_ncbi <- list()
for(i in 1:length(taxa_unique)){
  tax_hier_ncbi[[i]] <- classification(taxa_unique[[i]], db = "ncbi")
}

save(tax_hier_ncbi, file = "tax_hier_ncbi_primerbias20151205.RData")

tax_hier_collapser <- function(x)
{
  consol <- do.call(rbind, x)
  return(unique(consol[duplicated(consol), ]))
}
# 2,4,5,7,8
tax_hier_collapser(tax_hier_ncbi[[1]])
tax_hier_ncbi[[9]]

# collapse (intersect taxonomic hierarc)
tax_hier_intersect <- list()
for(i in 1:length(tax_hier_ncbi)){
  tax_hier_intersect[[i]] <- Reduce(intersect, 
         sapply(tax_hier_ncbi[[i]][!is.na(tax_hier_ncbi[[i]])], "[", 1, simplify = TRUE)
  )
}
names(tax_hier_intersect) <- names(taxa_unique)
# STILL a problem with 9! (because of "uncultered organism)
tax_hier_intersect

######## THIS IS IT
best_hit <- sapply(tax_hier_intersect, function(x) x[length(x)])
######## THIS IS IT
names(best_hit)
identical(names(best_evalue), names(best_hit))




#----------------------------------------------------------------------------------------
# GRAVEYARD
#----------------------------------------------------------------------------------------
# extract the names only (exclude rank name, e.g. "Genus")
names_only <- lapply(classifications, "[[", 1)
taxon_ranks <- as.character(unique(do.call(rbind, lapply(classifications, "[", 2))))
taxon_ranks[[2]]
# what is the group that is common to all results?
common_ancestor <- Reduce(intersect, names_only)

# FINAL_TABLE <-   cbind(query = names(best_hit), best_hit, best_evalue, best_bitscore)
# rownames(FINAL_TABLE) <- NULL
# write.csv(
  # x = FINAL_TABLE, 
  # file = "blast_hit_summary.csv", 
  # row.names = FALSE
  # )


# OTHER PLOTS
# plot bitscore against evalue
plot(
	x = blast_results[, evalue_col], 
	y = blast_results[, bitscore_col], 
	# log = "x", 
	xlab = "evalue", 
	ylab = "bitscore", 
	pch = 21, 
	col = "black", 
	bg = rgb(red = 0, green = 0, blue = 0, alpha = 0.1)
	)

