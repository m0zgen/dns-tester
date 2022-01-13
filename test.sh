#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-adm.in
# Check DNS services performance from IP list
# Reference: https://serverfault.com/questions/91063/how-do-i-benchmark-performance-of-external-dns-lookups/952809#952809

# Sys env / paths / etc
# -------------------------------------------------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

# Initial variables
# ---------------------------------------------------\
_DNS="1.1.1.1"
_TARGET="google.com"
_TARGETS=$1

if [[ -z $2 ]]; then
	_TESTS=3
else
	_TESTS=$2
fi

# Functions
# ---------------------------------------------------\
# Help information
usage() {

	echo -e "\nYou can use this script with several parameters:"
	echo -e "./$SCRIPT_NAME my-dns.txt"
	echo -e "* my-dns.txt - DNS servers IP list
\nAlso you can optionally set numbers of iterating tests:
/$SCRIPT_NAME my-dns.txt 5
* 5 - Number of test iterations
	"
	exit 1
}

if [ ! -f "$_TARGETS" ] || ! echo "$_TESTS"|egrep -q "[0-9]+" ; then
  usage
fi

spinner()
{
    local pid=$!
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

singleTest() {
	for i in `seq 1 $_TESTS`; do 
		result=`dig @$_DNS $_TARGET | awk '/Query time:/ {print " "$4}'`
		echo -e "Time (ms):$result from $_DNS to $_TARGET"
	done
}

statisticsTest() {
	for i in `seq 1 $_TESTS`; do 
		echo -e "Iterating: $i"
		for IP in `cat $_TARGETS`; do
		    time=`dig @$IP $site| awk '/Query time:/ {print " "$4}'`
		    IPtrans=`echo $IP|tr \. _`
		    eval `echo result$IPtrans=\"\\$result$IPtrans$time\"`
		done & spinner
	done

	echo -e "\nResult statistics:\n"

	for IP in `cat $_TARGETS`; do
	  IPtrans=`echo $IP|tr \. _`
	  printf "%-15s " "$IP"; echo -e `eval "echo \\$result$IPtrans"`|tr ' ' "\n"|awk '/.+/ {rt=$1; rec=rec+1; total=total+rt; if (minn>rt || minn==0) {minn=rt}; if (maxx<rt) {maxx=rt}; }
	             END{ if (rec==0) {ave=0} else {ave=total/rec}; printf "average %5i     min %5i     max %5i ms %2i responses\n", ave,minn,maxx,rec}'
	done
	echo ""
}

# Script inits
# ---------------------------------------------------\
# singleTest
statisticsTest


