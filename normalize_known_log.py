
with open("known_good.log", "rt") as kf:
  with open("normalized_good.log", "wt") as nf:
    for line in kf:
      if line[0] == '#':
        continue
      norm_line = line[:19] + "                  " + line[48:74] + line[86:]
      if norm_line[15] == "*":
        norm_line = norm_line[:15] + " " + norm_line[16:19] + "?" + norm_line[20:]
      nf.write(norm_line)
