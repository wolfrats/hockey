import re

with open("objects/skaters/ai.gd", "r") as f:
    code = f.read()

# opponent.x is an absolute coordinate (0 to 2011).
# We want to check if the opponent is in the opponent's half of the rink.
# Center of the rink is 1005.5
search_str = "if opponent.x * forward_dir > 0: # If in opponent's half"
replace_str = "if (opponent.x - 1005.5) * forward_dir > 0: # If in opponent's half"

code = code.replace(search_str, replace_str)

with open("objects/skaters/ai.gd", "w") as f:
    f.write(code)
