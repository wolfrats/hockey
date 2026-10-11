import sys

with open("menu/team_setup.gd", "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'home_difficulty_label.text =' in line:
        lines[i] = '\thome_difficulty_label.text = "AI: Hard" if value == 1 else "AI: Extra Hard" if value > 1.5 else "AI: Easy"\n'
    if 'away_difficulty_label.text =' in line:
        lines[i] = '\taway_difficulty_label.text = "AI: Hard" if value == 1 else "AI: Extra Hard" if value > 1.5 else "AI: Easy"\n'

with open("menu/team_setup.gd", "w") as f:
    f.writelines(lines)
