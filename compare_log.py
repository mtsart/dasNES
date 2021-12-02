def normalize_line(l):
  trimmed = l.rstrip()
  missingSpaces = 76 - len(trimmed)
  return trimmed + (" " * missingSpaces)

with open("normalized_good.log", "rt") as gf:
  with open("6502.log", "rt") as bf:
    with open("compare.log", "wt") as cf:
      done = False
      while not done:
        goodLine = gf.readline()
        if not goodLine:
          goodLine = "(end of file)"
          done = True
        goodLine = normalize_line(goodLine)
        badLine = bf.readline()
        if not badLine:
          badLine = "(end of file)"
          done = True
        badLine = normalize_line(badLine)
        if goodLine != badLine:
          done = True
          cf.write(goodLine + " -- DIFFERENT --\n")
          cf.write("GOOD: " + goodLine + "\n")
          cf.write("BAD:  " + badLine + "\n")
        else:
          cf.write(goodLine + "\n")
