f = open("debug.txt", "r")
g = open("tests/nestest.log", "r")

for line in f:
    gline = g.readline()
    if line[0:4] != gline[0:4]:
        print(f"Line mismatch: {line} != {gline}")
        break
