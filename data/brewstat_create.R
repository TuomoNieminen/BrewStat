# join brewdog rating and recipe data together
# Tuomo Nieminen 2017

ratings <- read.table("data/punk_ratings.csv", sep = ",")
recipes <- read.table("data/punk_recipes.csv", sep = ",")

# how many name matches
sum(ratings$beer_name %in% recipes$beer_name) # 86

# convert to lower case
beer_name1 <- tolower(ratings$beer_name)
beer_name2 <- tolower((recipes$beer_name))

# how mnay name matches now
sum(beer_name1 %in% beer_name2) # 96

# remove special characters
library(stringr)
beer_name1 <- str_replace_all(beer_name1, "[^[:alnum:]]", "")
beer_name2 <- str_replace_all(beer_name2, "[^[:alnum:]]", "")

# how many name matches now
sum(beer_name1 %in% beer_name2) # 109

# add new versions of names to data
ratings$beer_name2 <- beer_name1 %>% as.character
recipes$beer_name2 <- beer_name2

# join the data by the formatted names
brewstat <- dplyr::inner_join(ratings, recipes, by = "beer_name2")

# save
write.table(file = "data/brewstat.csv", brewstat, sep = ",")

# brewstat <- read.table("data/brewstat.csv", sep = ",")
# dim(brewstat)

# explore fuzzy joining possiblities. 
# results: would be better to do by hand, with the aid of similarity measures
#
# # compute full string distance matrix using longest common substring distance (lcs)
# library(stringdist)
# D <- stringdistmatrix(beer_name1, beer_name2, method = "lcs")
# 
# # match each recipe beername to a rating beername
# 
# name_lookup <- data.frame(ratings = beer_name1, recipes = "", sim = 0, stringsAsFactors = F)
# min_indx <- apply(D, 1, which.min)
# name_lookup[, 2] <- beer_name2[min_indx]
# name_lookup[, 3] <- apply(D, 1, min)
# 
# # divide the similarity by chracter lengths to get a better measure
# name_lookup$sim <- name_lookup$sim / mapply(function(x,y) nchar(x) + nchar(y), name_lookup$ratings, name_lookup$recipes)
