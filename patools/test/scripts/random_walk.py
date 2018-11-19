#!/usr/bin/python

import sys
import random
import math
import gen_struct
import subprocess

LES = [0.5, 105.5, 12, 3.5]

def parse_args():
  if len(sys.argv) < 8 or len(sys.argv) != 9 + int(sys.argv[7]) or float(sys.argv[5]) > float(sys.argv[6]):
    print "Usage: %s <NUM> <DIR> <SOURCE_SIZE> <TARGET_SIZE> <MIN> <MAX> <N> <NUM_PRED-0> ... <NUM_pred-N>" % sys.argv[0]
    print "NUM         -- Number of embeding instances to generate"
    print "SOURCE_SIZE -- Size of the source structure's universe"
    print "TARGET_SIZE -- Size of the target structure's universe"
    print "MIN         -- minimum value of any parameter [0, max]"
    print "MAX         -- maximum value of any parameter [min, 1]"
    print "N           -- maximum arity of any predicate"
    print "NUM_PRED-i  -- number of predicates with arity i"
    sys.exit(1)
  return (int(sys.argv[1]), sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6]), map(int, sys.argv[8:]))

def log_expected_solutions(su, tu, npreds, params):
  solutions = 0
  for i in xrange(su):
    solutions += math.log(tu - i)

  power = 1
  for i in xrange(len(npreds)):
    exp = npreds[i] * power
    solutions += exp * math.log(params[2 * i] * (params[2 * i + 1] - 1) + 1)
    power *= su

  return solutions

def expected_solutions(su, tu, npreds, params):
  solutions = 1
  for i in xrange(su):
    solutions *= tu - i

  power = 1
  for i in xrange(len(npreds)):
    exp = npreds[i] * power
    solutions *= math.pow(params[2 * i] * (params[2 * i + 1] - 1) + 1, exp)
    power *= su
  return solutions

def dx(x, su, tu, npreds, params):
  i = x / 2
  exp = npreds[i] * math.pow(su, i)
  ddx = exp * (params[2 * i] if x % 2 else (params[2 * i + 1] - 1))
  ddx /= params[2 * i] * (params[2 * i + 1] - 1) + 1
  return ddx

def random_walk(su, tu, npreds, minVal, maxVal, params):
  gamma = 0.00001
  choices = [i for i in xrange(len(params)) if npreds[i/2] != 0]

  les = LES[len(npreds) - 1]

  sol = log_expected_solutions(su, tu, npreds, params)
  while abs(sol - les) > 0.005:
    dir = random.choice(choices)
    ddx = abs(sol - les) / (sol - les) * dx(dir, su, tu, npreds, params)
    params[dir] = min(maxVal, max(minVal, params[dir] - gamma * ddx))
    sol = log_expected_solutions(su, tu, npreds, params)
  return params

def find_params(su, tu, npreds, minVal, maxVal):
  return random_walk(su, tu, npreds, minVal, maxVal, [random.random() if npreds[i / 2] != 0 else 0 for i in xrange(len(npreds) * 2)])

NTrue = NFalse = NUnsolved = 0
def gen_hard_struct(su, tu, params, fname):
  global NTrue, NFalse, NUnsolved
  nTrue = nFalse = 0
  while nTrue + nFalse < 10: # Generate upto 10 structures
    out = open(fname, "w")
    gen_struct.main(su, tu, len(params) / 3 - 1, params, out)
    out.close()

    proc = subprocess.Popen(["/home/charlie/git_repos/duet/patools/test/scripts/run_suite_short.sh", fname], stdout=subprocess.PIPE)
    lines = [line.strip().split() for line in proc.stdout.readlines()]

    if "True" in lines[1]:
      nTrue += 1
      NTrue += 1
    elif "False" in lines[1]:
      nFalse += 1
      NFalse += 1
    else:
      NUnsolved += 1
    if lines[0].count("--"):
      return True
    if abs(nTrue - nFalse) > 2: # if far from phase shift then try a different random walk
      break
  return False

def main():
  args = parse_args()

  N = args[0]
  dir = args[1]
  su = args[2]
  tu = args[3]
  minVal = args[4]
  maxVal = args[5]
  npreds = args[6]

  j = 0
  while j != N:
    p = find_params(su, tu, npreds, minVal, maxVal)
    params = []
    for i in xrange(len(npreds)):
      params.append(npreds[i])
      params.append(p[2 * i])
      params.append(p[2 * i + 1])
    if gen_hard_struct(su, tu, params, dir + "/embeds%03d.struct" % j):
      j += 1
    print NTrue, NFalse, NUnsolved


if __name__ == "__main__":
  random.seed()
  main()
