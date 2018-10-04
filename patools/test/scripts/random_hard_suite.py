#!/usr/bin/python

import sys
import random
import subprocess
import gen_struct

def parse_args():
  if len(sys.argv) != 4:
    print "Usage: %s <NUM> <DIR> <PARAMETER_FILE>" % (sys.argv[0])
    sys.exit(1)
  return (int(sys.argv[1]), sys.argv[2], sys.argv[3])

def main():
  (N, out_dir, p_file) = parse_args()
  params = [map(float, line.strip().split()) for line in open(p_file, "r").readlines()]
  su = int(params[0][0])
  tu = int(params[0][1])
  params = params[1:]
  ar = len(params[0]) / 3 - 1

  for i in xrange(len(params)):
    params[i][::3] = map(int, params[i][::3])

  i = 0
  while i != N:
    p = random.choice(params)

    fname = out_dir + ("/embed%03d.struct" % i)
    out = open(fname, "w")
    gen_struct.main(su, tu, ar, p, out)
    out.close()

    proc = subprocess.Popen(["/home/charlie/git_repos/duet/patools/test/scripts/run_suite_short.sh", fname], stdout=subprocess.PIPE)
    lines = [line.strip().split() for line in proc.stdout.readlines()]

    print p, lines

    if lines[0].count("--") > 0:
      print "Added %s @ %s %s" % (fname, lines[1], lines[0])
      i += 1

if __name__ == "__main__":
  random.seed()
  main()
