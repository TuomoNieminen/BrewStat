# Retrieve ratebeer ratings for BrewDog beers
# Tuomo Nieminen 2017

# url to retrieve ratings from
url <- "https://www.ratebeer.com/Ratings/Beer/ShowBrewerBeers.asp?BrewerID=8534"

# the xml path to the html ratings table (found using SelectorGadget)
xpath <-  '//*[(@id = "brewer-beer-table")]'

# xpath to elements we wish to exclude from the table. 
xpath_exclude <-  '//span[contains(concat( " ", @class, " " ), concat( " ", "real-small hidden-xs", " " ))]'

library(rvest)

# read html as xml nodes
html <- read_html(url)

# exclude nodes describing the beer type. 
# This is done because a single column includes beer names and other info. (we want the beer names separately)
# What this actually achieves is not clear, perhaps gives the label of the element instead...
# This turns out to work anyway because the label info is separated from beernames with multiple spaces and includes even more information
tmp <- xml_find_all(html, xpath_exclude) %>% xml_remove

# create a data frame from the html table
beer_ratings <- html_nodes(html, xpath = xpath) %>% html_table(header = T, fill = T)
beer_ratings <- beer_ratings[[1]]

# remove two ghost columns
beer_ratings <- beer_ratings[, -c(4,8)]

# Problem is the the first column ('Name') includes the beer names along with other information.
# Use string manipulation to fix
# -------------------------------------

# keep only beers brewed for BrewDog
brewdog_ratings <- dplyr::filter(beer_ratings, grepl("BrewDog", beer_ratings$Name))

# exclude collaboration beers (they have a '/' in the 'Name' column)
brewdog_ratings <- dplyr::filter(brewdog_ratings, !grepl("/", brewdog_ratings$Name))

# remove the 'BrewDog' from the 'Name' column to get only the beer name and type
nametype <- gsub("BrewDog ", "", brewdog_ratings$Name)

# remove unneeded text inside parenthesis such as '(retired)'
nametype <- gsub("*\\(.*?\\) *", "", nametype)

# split text to beer name and beer type according to two or more whitespace
name_type <- reshape2::colsplit(nametype, "\\s{2,}", names = c("beer_name", "beer_type"))

# add beername and type to the rating data frame
ratings <- cbind(brewdog_ratings, name_type)

# remove the 'Name' column and rename the columns
ratings <- ratings[-1]
names(ratings)[-6] <- paste0("ratebeer_", names(ratings)[-6])
names(ratings)[5] <- "ratebeer_rank"

# remove duplicated beer names
ratings <- ratings[!duplicated(ratings$beer_name),]

# save
write.table(file = "data/punk_ratings.csv", ratings, sep = ",")

# ratings <- read.table("data/punk_ratings.csv", sep = ",")
# dim(ratings) # [1] 337   7
