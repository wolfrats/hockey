import re

with open("objects/skaters/ai.gd", "r") as f:
    code = f.read()

code = code.replace("if difficulty == 1:", "if difficulty >= 1:")
code = code.replace("if difficulty == 1 and other_team_has_puck", "if difficulty >= 1 and other_team_has_puck")
code = code.replace("if difficulty == 1 and curSkater.global_position.distance_to(target_pos) < 60:", "if difficulty >= 1 and curSkater.global_position.distance_to(target_pos) < 60:")
code = code.replace("10.0 if difficulty == 1 else 3.0", "10.0 if difficulty >= 1 else 3.0")
code = code.replace("500 if difficulty == 1 else 300", "500 if difficulty >= 1 else 300")
code = code.replace("0.0 if difficulty == 1 else 1.0", "0.0 if difficulty >= 1 else 1.0")


with open("objects/skaters/ai.gd", "w") as f:
    f.write(code)

with open("objects/skaters/goalie.gd", "r") as f:
    code = f.read()

code = code.replace("if difficulty == 1 and puck_node.posessor and puck_node.posessor.charging:", "if difficulty >= 1 and puck_node.posessor and puck_node.posessor.charging:")

with open("objects/skaters/goalie.gd", "w") as f:
    f.write(code)
