import re

with open("objects/skaters/ai.gd", "r") as f:
    code = f.read()

search_str = """	if difficulty >= 1:
		current_strategy = 2"""

replace_str = """	if difficulty == 1:
		current_strategy = 2
	elif difficulty == 2:
		current_strategy = 5"""

code = code.replace(search_str, replace_str)


with open("objects/skaters/ai.gd", "w") as f:
    f.write(code)
