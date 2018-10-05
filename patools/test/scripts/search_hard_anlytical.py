#!/usr/bin/python

import sys
import random
import subprocess
import gen_struct
import math

random.seed()

su = 36
tu = 43

ar = 1
init_params = [0, 0, 0, 3, 0, 0]
free = [4, 5]

max = int(sys.argv[1])
eps = 0.0000001

def log_expected_solutions(params):
  solutions = 1.0
  for i in xrange(su):
    solutions *= tu - i

  power = 1
  for i in xrange(len(params) / 3):
    exp = params[3 * i] * power
    solutions *= math.pow(params[3 * i + 1] * (params[3 * i + 2] - 1) + 1, exp)
    power *= su

  return math.log(solutions)

print su, tu

n = 0
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

    log_sol = log_expected_solutions(params)

    if abs(log_sol - 4) < 0.01:
      print " ".join(map(str, params))
      n += 1
      break
    delta /= 2
    d = delta * (-1 if free in [4, 7, 10] else 1)
    if log_sol > 0:
      val -= d
    else:
      val += d
