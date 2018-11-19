#! /usr/bin/python
import matplotlib.pyplot as plt

def cactus_plot(data, *args, **kwargs):
    plt.plot(data, data, *args, **kwargs)

solver = [("MatchEmbeds","s", "b"),
          ("CryptoMiniSat","o", "y"),
          ("Lingeling","h", "r"),
          ("HaifaCSP","*", "m"),
          ("Gecode","d", "c"),
          ("VF2","^", "g"),
          ("OrTools","p", "orange"),
          ("Glasgow", "h", "pink")]
# s - square, v ^ < > - triangles, o - circe, p - pentagon, * - star, h H - hexagon, x - x, d D - diamond


for (label,marker, color) in solver:
    d = []
    cactus_plot(d[:], '-', marker=marker, color=color, label=label)

plt.xlabel('Instances Solved')
plt.ylabel('Time (s)')
plt.ylim((0,100))
plt.xlim((0,100))
#plt.yscale('log')
#plt.legend(bbox_to_anchor=(0.38,1.0), loc=2)
plt.legend(loc=0, ncol=4, prop={'size': 14})
plt.show()
