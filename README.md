# IRC

Demo to demonstrate how to talk to an ESP32 device through IRC.

## Local Development

Any IRC server should work, but we use ngircd.

We compile from sources, so we can enable the debugging support.

```
git clone https://github.com/ngircd/ngircd.git
cd ngircd
./autogen.sh
./configure --prefix=$PWD/out --enable-sniffer --enable-debug
make && make install
out/sbin/ngircd -n -s
```
