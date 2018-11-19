External solvers used to benchmark embedding algorithm:
* Gecode v6.0.1
* Google's OrTools v6.9
* HaifaCSP v1.3.0
* Crypto-MiniSat v5.0
* Lingeling vbcj
* Boost's implementation of VF2 Algorithm (labeled subgraph isomorphism) v1.6.5


```
# Gecode
wget https://github.com/Gecode/gecode/archive/release-6.0.1.tar.gz
tar -xvzf release-6.0.1.tar.gz
cd release-6.0.1.tar.gz
make && make install

# Google's OrTools
git clone https://github.com/google/or-tools.git
cd or-tools
make third_party && make fz

# HaifaCSP
wget http://tx.technion.ac.il/~mveksler/HCSP/hcsp-1.3.0-x86_64.tar.xz
tar -xJf hcsp-1.3.0-x86_64.tar.xz

# Crypto-MiniSat
sudo apt-get install build-essential cmake
# not required but very useful
sudo apt-get install zlib1g-dev libboost-program-options-dev libm4ri-dev libsqlite3-dev
git clone https://github.com/msoos/cryptominisat.git
cd cryptominisat
mkdir build && cd build
cmake ..
make
sudo make install
sudo ldconfig

# Lingeling
wget http://fmv.jku.at/lingeling/lingeling-bcj-78ebb86-180517.tar.gz
tar -xvzf lingeling-bcj-78ebb86-180517.tar.gz
cd lingeling-bcj-78ebb86-18017
./configure.sh && make

# Boost
apt-get install libboost-all-dev
```
