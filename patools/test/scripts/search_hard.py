#!/usr/bin/python

import sys
import random
import subprocess
import gen_struct


random.seed()

su = 36
tu = 43
ar = 1

init_params = [0, 0, 0, 3, 0, 0]

print su, tu

n = 0
max = int(sys.argv[1])
eps = 0.00001
while n < max:
  free = [4, 5]
  fixed = random.sample(free, len(free) - 1)

  params = init_params[:]

  for x in fixed:
    params[x] = random.random()
    free.remove(x)

  free = free[0]

  val = 1
  if free in [4, 7, 10]:
    val = 0
  delta = 1.0
  while delta > eps and 0 <= val and val <= 1:
    params[free] = val

    nTrue = nFalse = 0
    fname = "embed.struct"
    while nTrue + nFalse != 10:
      out = open(fname, "w")
      gen_struct.main(su, tu, ar, params, out)
      out.close()

      proc = subprocess.Popen(["/home/charlie/git_repos/duet/patools/test/scripts/run_solver_short.sh", fname], stdout=subprocess.PIPE)
      lines = [line.strip().split() for line in proc.stdout.readlines()]

      if "True" in lines[0]:
        nTrue += 1
      elif "False" in lines[0]:
        nFalse += 1

    if abs(nTrue - nFalse) <= 2:
      print " ".join(map(str, params))
      n += 1
      break
    delta /= 2
    d = delta * (-1 if free in [4, 7, 10] else 1)
    if nTrue > nFalse:
      val -= d
    else:
      val += d
