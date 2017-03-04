# This script retrieves JSON format punk-api beer recipes from a github repo
# and combines the recipes into a single tabular format
#
# data source: https://github.com/samjbmason/punkapi-db/tree/master/data
# author: Tuomo Nieminen 2017

rm(list=ls())

library(httr)

repo <- "samjbmason/punkapi/"

# list all data files in the repo using GitHub API so we can retrieve the files
url <- paste0("https://api.github.com/repos","/", repo, "git/trees/master?recursive=1")
req <- GET(url)
stop_for_status(req)
filelist <- unlist(lapply(content(req)$tree, "[", "path"), use.names = F)
recipe_files <- filelist[grep("data/",filelist)]


# retrieve each JSON file from the repos data folder and create a (deep) list of beer recipes
require(jsonlite)
recipe_deep <- lapply(recipe_files,function(file) {
  url <- paste0("https://raw.githubusercontent.com/", repo, "master/", file)
  jsonlite::fromJSON(txt = url)
})

# move to a bit wider format by unlisting (used later to extract malt and hop info)
recipe_list <- lapply(recipe_deep, unlist, recursive = F)


# extract method infos
# --------------------

beer_methods <- lapply(recipe_deep, function(beer) {
  methods <- unlist(beer$method)
  if(length(methods) < 1) {
    #cat("no methods for ", beer$name)
    return(NULL)
  }
  c(beer_name=beer$name, methods)
})

# assign all method variables to all beers by adding NA values if there are no methods related to the beer
# this is needed to create a data frame
method_names <- unique(unlist(lapply(beer_methods, names)))
new_methods <- lapply(beer_methods, function(methods) {
  added_methods <- method_names[!method_names %in% names(methods)]
  long_methods <- c(methods, rep(NA, length(added_methods)))
  names(long_methods) <- c(names(methods), added_methods)
  as.list(long_methods)
  }
)

# create a method data frame
methods <- do.call(rbind.data.frame, new_methods)
library(dplyr)

# convert factors to characters 
methods <- mutate_if(methods, sapply(methods, is.factor), as.character) 

# convert value and duration columns to numerics
f <- function(x) grepl("value*", x) | grepl("*duration*", x)
methods <- mutate_if(methods, sapply(names(methods), f), as.numeric)


# extract hop infos
# ---------------

beer_hops <- lapply(recipe_list, function(beer) {
  df <- data.frame(beer$ingredients.hops)
  if(nrow(df)==0) {
    cat("no hops:", beer$name)
    return(NULL)
  }
  
  # hack to get rid of weird formatting (data frame inside data frame)
  df <- cbind(df[,c("name", "attribute", "add")],df[,"amount"])
  df$name <- tolower(df$name)
  df$attribute[df$attribute == "flavoour"] <- "flavour"
  df$add[df$add=="midele"] <- "middle"
  
  # combine hop names wih hop attributes to enable wide format (one row per beer)
  df$name <- paste0("Hop.",df$name, ".", df$attribute, ".", df$add)
  df <- df[,c("name", "value")]
  df <- df[!duplicated(df$name),]
  
  df$beer_name <- beer$name
  df
})

# combine hops data into single data frame
hops <- do.call(rbind, beer_hops)

# move to wide format where each row is a beer
hops <- tidyr::spread(hops, key = name, value = value)
hops[is.na(hops)] <- 0


# extract malt infos
# -----------------

beer_malts <- lapply(recipe_list,function(beer) {
  
  df <- data.frame(beer$ingredients.malt)
  if(nrow(df)==0) {
    cat("no malt:", beer$name)
    return(NULL)
  }
  # hack to get rid of weird formatting (data frame inside data frame)
  df <- cbind(df$name, df$amount)
  colnames(df)[1] <- "name"
  df$name <- paste0("Malt.", tolower(df$name))
  df$beer_name <- as.character(beer$name)
  df
})

# combine malt info into single data frame
malts <- do.call(rbind, beer_malts)
colnames(malts)[-4] <- paste0("malt_",colnames(malts)[-4])

# move to wide format where each row is a beer
malts <- tidyr::spread(malts, key = "malt_name", value = "malt_value")
malts[is.na(malts)] <- 0


# Now combine the rest of the recipe infos to a data frame
# ------------------------------------------------
  
# remove the already extracted elemets from the original list
pruned_beerlist <- lapply(recipe_deep, function(recipe) {
  recipe$method <- NULL 
  recipe$ingredients <- NULL
  unlist(recipe, recursive=F)
})

# assign all variables to all beers by adding NA's id the variable is missing
# this is needed to create a data frame
all_variables <- unique(unlist(lapply(pruned_beerlist, names)))

beer_infos <- lapply(pruned_beerlist, function(recipe) {
  new_variables <- all_variables[!all_variables %in% names(recipe)]
  new_recipe <- c(recipe, rep(NA, length(new_variables)))
  names(new_recipe) <- c(names(recipe), new_variables)
  as.data.frame(new_recipe)
})
# combine to a data frame

infos <- do.call(rbind, beer_infos)

# change name -> beer_name for merging
names(infos)[names(infos)=="name"] <- "beer_name"

# factors to character
infos <- mutate_if(infos, sapply(infos, is.factor), as.character)


# merge data into single data frame
# ---------------------------------

beer_datas <- list("info" = infos, "hops" = hops, "malts" = malts, "methods" = methods)
beer <- beer_datas %>%
  Reduce(function(df1,df2) dplyr::full_join(df1, df2, by="beer_name"), .)

# save to file
write.table(file = "data/punk_recipes.csv", beer, sep = ",")

# beer <- read.table("data/punk_recipes.csv", sep = ",")
# dim(beer) # [1] 234 371
