#!/usr/bin/python

import random
import sys

def parse_args():
  if len(sys.argv) < 7 or len(sys.argv) != (7 + 3 * int(sys.argv[3])):
    print "Usage: %s SOURCE_SIZE TARGET_SIZE MAX_ARITY <NUM_PREDS-0> <SOURCE_DENSITY-0> <TARGET_DENSITY-0> ... <NUM_PREDS-N> <SOURCE_DENSITY-N> <TARGET_DENSITY-N>" % sys.argv[0]
    sys.exit(0)
  return (int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), map(float, sys.argv[4:]))

def int2NumList(base, dimensions, i):
  ret = [0 for j in xrange(dimensions)]
  j = 0
  while i != 0:
    ret[j] = i % base
    i /= base
    j += 1
  return ret

def gen_struct(size, offset, max_arity, params, out):
  out.write("{")
  for i in xrange(size):
    if i != 0:
      out.write(", ")
    out.write("v(%d)" % (i + 1))

  max_sel = 1
  for ar in xrange(max_arity+1):
    n = int(params[3*ar])
    d = params[3*ar + offset]

    for i in xrange(n):
      p = "p_%d_%d" % (ar, i)
      for j in xrange(max_sel):
        if random.random() < d:
          out.write(", " + p + "(")
          comma = False
          for id in int2NumList(size, ar, j):
            if comma:
              out.write(", ")
            comma = True
            out.write("%d" % (id + 1))
          out.write(")")
    max_sel *= size
  out.write("}\n")

def main(source_universe, target_universe, max_arity, params, out = sys.stdout):
  random.seed()
  gen_struct(source_universe, 1, max_arity, params, out) # source structure
  gen_struct(target_universe, 2, max_arity, params, out) # target structure

if __name__ == "__main__":
  (su, tu, ar, p) = parse_args()
  main(su, tu, ar, p)

