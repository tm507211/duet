#!/usr/bin/python

import sys

def parse_args():
  if len(sys.argv) < 2:
    print "Usage: %s <RES_1> <RES_2> ... <RES_N>" % sys.argv[0]
    sys.exit(1)

  return sys.argv[1:]

def read_file(fname):
  data = [line.strip().split() for line in open(fname, "r").readlines()]
  data = [[x] for x in zip(*data[:-1])] + [[" ".join(data[-1])]]
  return data

def join_files(data1, data2):
  for i in xrange(1,len(data1)):
    data1[i] += data2[i]
  return data1

def main():
  args = parse_args()
  data = reduce(join_files, map(read_file, args))
  for i in xrange(len(data[0][0])):
    line = data[0][0][i]
    for d in data[1:-1]:
      line += "\t".join([""] + [p[i] for p in d])
    print line
  for i in xrange(len(data[-1])):
    print "Fail%d: %s" % (i + 1, data[-1][i].split()[1])
#  for line in reduce(join_files, map(read_file, args)):
#    print "\t".join(line)

if __name__ == "__main__":
  main()
