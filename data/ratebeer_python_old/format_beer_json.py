import json


# Reads a json file containting beer information, adds missing value tags to all the beers that are
# missing features so that all beers have all features. Saves the new formatted json to output file
def add_missing_value_tags(input_file: str = "first5beers.json", output_file: str ="formatted_beers.json", missing_value_tag: str ="NA") -> None:
    with open(input_file, "r") as f:
        beer_dict = json.load(f)

    all_features = set([feature for beer in beer_dict for feature in beer_dict[beer]])

    # Add missing values
    for beer in beer_dict:
        for item in all_features:
            if item not in beer_dict[beer]:
                beer_dict[beer][item] = missing_value_tag

    # Add beer url to features and convert dictionary of beers to just list of beers
    output_list = []
    for beer in beer_dict:
        beer_dict[beer]["url"] = beer
        output_list.append(beer_dict[beer])

    with open(output_file, "w") as f:
        json.dump(output_list, f)


if __name__ == "__main__":
    add_missing_value_tags()

