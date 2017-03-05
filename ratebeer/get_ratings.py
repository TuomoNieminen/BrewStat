#!py 3

import datetime
import time
import json
import re
import requests
from bs4 import BeautifulSoup

BASE_URL = "http://www.ratebeer.com"
BREWDOG_URL = "http://www.ratebeer.com/brewers/brewdog/8534/"


# Not used at the moment
def get_list_of_beer_links_from_url(current_url: str) -> list:
    html = requests.get(current_url).content
    soup = BeautifulSoup(html, "lxml")

    # Matches beer links, but does not match top links, for example /beer/top-50-custom/ does not get matched.
    # We only want links to actual beers, not to top lists
    beer_link_pattern = r'^/beer/.+?/[0-9]+/$'

    beer_links = []

    tags = soup("a")
    for index, tag in enumerate(tags):
        next_url = tag.get("href", None)

        if next_url:
            hit = re.findall(beer_link_pattern, next_url)
            if hit:
                beer_links.append(hit[0])

    return beer_links


# Format of URL should be like http://www.ratebeer.com/brewers/brewdog/8534/
# Extracts beer links and links to additional brewery pages from the same brewery as this
# Returns tuple of lists, first list contains beer links, second tuple contains brewery links (of this same brewery)
def get_links_from_brewery_url(brewery_url: str) -> ([str], [str]):
    # Extract brewery name from the url, this will be used later on to match
    # more pages containing beers from this brewery
    this_brewery_name = re.findall(r'/brewers/(.*?)/', brewery_url)[0]

    html = requests.get(brewery_url).content
    soup = BeautifulSoup(html, "lxml")

    # Match for beer links, this also matches links to rate beer page which we want to exclude
    beer_link_pattern = r'^/beer/.+?/[0-9]+/$'
    beer_rate_link_pattern = r'^/beer/rate/[0-9]+/$'
    beer_links = []

    # Match brewers links to find more pages
    brewer_link_pattern = r'^/brewers/' + this_brewery_name
    brewer_links = []

    for link in soup.find_all("a", href=True):
        this_link = link["href"]
        # Is this a link to beer?
        if re.match(beer_link_pattern, this_link) and not re.match(beer_rate_link_pattern, this_link):
            beer_links.append(this_link)
        # Is this a link to another page of this brewery
        if re.match(brewer_link_pattern, this_link):
            brewer_links.append(this_link)

    return beer_links, brewer_links


# Crawls current brewery page and all other pages of this same brewery that it finds
# Returns a list of beer links that was found in any of the pages
# Returned list contains each link only once
def crawl_all_beer_pages_from_single_brewery(start_page: str) -> [str]:
    # Make a set of seen links, one for beers one for breweries:
    visited_beers, visited_breweries = set(), {start_page}
    # brewery links and add current page as root
    brewery_stack = [start_page]
    beer_stack = []

    i = 0

    while brewery_stack:
        current_page = brewery_stack.pop()
        visited_breweries.add(current_page)

        if True:
            i += 1
            print(i, "Current page", current_page)

        beer_links, brewery_links = get_links_from_brewery_url(current_page)

        for brewery in brewery_links:
            if brewery not in visited_breweries:
                # We have to add domain to the urls:
                brewery_stack.append(BASE_URL + brewery)
                visited_breweries.add(brewery)

        for beer in beer_links:
            if beer not in visited_beers:
                beer_stack.append(beer)
                visited_beers.add(beer)

    return beer_stack


# Goes to a single beer link page and returns the parsed contents
def parse_single_beer_link(beer_url: str, base_url: str=BASE_URL) -> dict:
    full_url = base_url + beer_url
    html_contents = requests.get(full_url).content

    beer_info = {}

    soup = BeautifulSoup(html_contents, "lxml")

    # Ugly hack to spot aliases, for example /beer/brewdog-tokio/267256/ is an alias for tokyo beer
    if "Proceed to the aliased beer" in soup.text:
        beer_info["Alias for another beer"] = True
        return beer_info

    # the div we want doesn't have an id, so we use it's sibling's id to find it
    middle_tag = soup.find(id="tdL").next_sibling.contents[0]

    # The first child of middle_tag contains brewery information, while the second one contains ratings information
    brewery_info = middle_tag.contents[0]
    ratings_info = middle_tag.contents[1]

    # Add basic features that are easy to find
    beer_info["Brewery Name"] = brewery_info.find(id="_brand4").text
    beer_info["Serve in"] = brewery_info.find(id="modal").next_sibling.text
    beer_info["Style"] = brewery_info.find(href=re.compile(r'/beerstyles/')).text
    beer_info["Name"] = soup.find(class_="user-header").find(itemprop="name").text

    # This finds ratings, will match both MEAN and WEIGHTED AVG, however most beers only have WEIGHTED AVG
    ratings_tags = ratings_info.find_all("a", {"name": "real average"})
    for match in ratings_tags:
        rating_regexp = r'([0-9]\.?[0-9]*)/'
        rating_value = re.findall(rating_regexp, match.contents[1].text)[0]
        beer_info[match.contents[0]] = rating_value

    # Find featured such as RATINGS (contains number of ratings), ABV, IBU, etc.
    # Note that not all beers have all features available
    abbr_tags = ratings_info.find_all("abbr")
    for item in abbr_tags:
        key = item.text.strip()
        # RATINGS have slightly different position in the html tree than other features
        if key != "RATINGS:":
            beer_info[key] = item.next_sibling.next_sibling.text
        else:
            beer_info[key] = item.next_sibling.text

    # Add timestamp in UTC
    beer_info["UTC timestamp"] = str(datetime.datetime.utcnow())
    # Add info box text, if it exists
    if middle_tag.find(id="_description3"):
        beer_info["Commercial Description"] = middle_tag.find(id="_description3").text

    return beer_info


def parse_pages_and_save(link_list: list, save_filename: str, maxiters: int = None) -> None:
    all_dictionaries = {}

    start_time = time.time()

    parse_times = []
    link_count = maxiters if maxiters else len(link_list)

    for i, link in enumerate(link_list, start=1):
        print(i, "/", link_count, "Percentage done: ", "{:.3f}".format(i / link_count), "Current link", link)
        all_dictionaries[link] = parse_single_beer_link(link)
        parse_times.append(time.time() - start_time)
        if i == maxiters:
            break

    with open(save_filename, "w") as f:
        json.dump(all_dictionaries, f)

    print("Total time", "{:.2f}".format(parse_times[-1]), "seconds")


# Finds all beer links from given brewery url, for example http://www.ratebeer.com/brewers/brewdog/8534/ and
# saves them as a json list to a file
def save_brewery_links_to_json(url: str, filename: str) -> None:
    brewery_urls = crawl_all_beer_pages_from_single_brewery(url)

    with open(filename, "w") as f:
        json.dump(brewery_urls, f)


# Parses all the beer links from a given file and saves the contents to saveto_filename
# Optional argument to limit the number of beer links parsed
def save_beer_links_to_json(link_filename: str, saveto_filename: str, max_link_count: int = None) -> None:
    with open(link_filename, "r") as f:
        beer_links = json.load(f)

    parse_pages_and_save(beer_links, saveto_filename, max_link_count)


if __name__ == "__main__":
    link_filename = "brewdog_beer_links.json"
    output_filename = "data/brewdog_ratebeer.json"
    save_brewery_links_to_json(BREWDOG_URL, link_filename)
    save_beer_links_to_json(link_filename, output_filename, 5)
