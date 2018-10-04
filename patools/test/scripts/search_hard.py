#!/usr/bin/python

import sys
import random
import subprocess
import gen_struct


random.seed()

out_dir = "/home/charlie/git_repos/duet/patools/test/hard4"
su = 12
tu = 30
ar = 3

params = [0, 0, 0, 10, 0, 0, 5, 0, 0, 5, 0, 0]

PARAMS = [[0, 0, 0, 10, 0.00943999830103, 0.0487997176315, 5, 0.31004465645,   0.875,          5, 0, 0],
          [0, 0, 0, 10, 0.0610841939364,  0.433231225137,  5, 0.512517957292,  0.921875,       5, 0, 0],
          [0, 0, 0, 10, 0.24650951358,    0.841224554713,  5, 0.61261461349,   0.9375,         5, 0, 0],
          [0, 0, 0, 10, 0.333409227291,   0.673828125,     5, 0.0342163143783, 0.541378584736, 5, 0, 0],
          [0, 0, 0, 10, 0.149715273213,   0.5625,          5, 0.36644769514,   0.913628895306, 5, 0, 0],
          [0, 0, 0, 10, 0.183215742587,   0.46875,         5, 0.768186952728,  0.98322406413,  5, 0, 0],
          [0, 0, 0, 10, 0.511656965266,   0.918991283675,  5, 0.489449529612,  0.91796875,     5, 0, 0],
          [0, 0, 0, 10, 0.106110643987,   0.34375,         5, 0.199297034355,  0.953605655326, 5, 0, 0],
          [0, 0, 0, 10, 0.0275446826664,  0.25,            5, 0.549530179741,  0.926211368283, 5, 0, 0],
          [0, 0, 0, 10, 0.27779980457,    0.916092863824,  5, 0.805281697408,  0.953125,       5, 0, 0]]

n = 0
max = int(sys.argv[1])
eps = 0.00001
while n < max:
  free = [10, 11]
  fixed = random.sample([10, 11], 1)

  params = random.choice(PARAMS)
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
    fname = out_dir +("/embed000.struct")
    for k in xrange(10):
      out = open(fname, "w")
      gen_struct.main(su, tu, ar, params, out)
      out.close()

      proc = subprocess.Popen(["/home/charlie/git_repos/duet/patools/test/scripts/run_solver_short.sh", fname], stdout=subprocess.PIPE)
      lines = [line.strip().split() for line in proc.stdout.readlines()]

      if "True" in lines[0]:
        nTrue += 1
      elif "False" in lines[0]:
        nFalse += 1

    print params, nTrue, nFalse

    if nTrue == nFalse:
      print " ".join(map(str, params))
      n += 1
      break
    delta /= 2
    d = delta * (-1 if free in [4, 7, 10] else 1)
    if nTrue > nFalse:
      val -= d
    else:
      val += d
