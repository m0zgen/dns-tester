## DNS query speed testing

* `test.sh` - is script which reading `my-dns.txt` file and test DNS with `dig` command

### Usage:

You can use this script with several parameters:
```bash
./test.sh my-dns.txt
```

Also you can optionally set numbers of iterating tests (default is 3):
```bash
/test.sh my-dns.txt 5
```

### Additional tools

You can use `dnseval`:

```bash
dnseval -f my-dns.txt -c 10 1.1.1.1
```

Or `dnsping`:
```bash
dnsping.py -c 5 --dnssec --flags --tls -t AAAA -s 1.1.1.1 ripe.net
```

Or `dnstrace`:
```bash
docker run redsift/dnstrace -n 50 -c 10 --server 1.1.1.1 --recurse ripe.net
```