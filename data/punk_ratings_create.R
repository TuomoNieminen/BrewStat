library(rvest)

url <- "https://www.ratebeer.com/Ratings/Beer/ShowBrewerBeers.asp?BrewerID=8534"
beer_ratings <- url %>%
  read_html() %>%
  html_nodes(xpath='//*[(@id = "brewer-beer-table")]') %>%
  html_table(header = T, fill = T)

beer_ratings <- beer_ratings[[1]]
