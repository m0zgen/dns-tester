#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-adm.in
# Check DNS services performance from IP list
# Reference: https://serverfault.com/questions/91063/how-do-i-benchmark-performance-of-external-dns-lookups/952809#952809

# Sys env / paths / etc
# -------------------------------------------------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd); cd $SCRIPT_PATH
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

# Initial variables
# ---------------------------------------------------\
# Notify in colors
# ---------------------------------------------------\

_DEFAULT_LIST="default.txt"
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
	echo -e "./$SCRIPT_NAME $_DEFAULT_LIST"
	echo -e "* my-dns.txt - DNS servers IP list
\nAlso you can optionally set numbers of iterating tests:
/$SCRIPT_NAME $_DEFAULT_LIST 5
* 5 - Number of test iterations
	"
    echo -e "Additional parameters:
-r - Set custom resolver DNS IP
-d - Target resolve domain name
-a - Add IP to $_DEFAULT_LIST
-s - Sort IP list $_DEFAULT_LIST or custom with -l parameter
"
	exit 1
}

# Checks arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--resolver) _RESOLVER=1 _RESOLVER_DATA=$2; ;; # Custom resolver
        -d|--domain) _DOMAIN=1 _DOMAIN_DATA=$2; ;; # Like as target
        -a|--add) _ADD=1 _ADD_DATA=$2; ;; # Add IP to default.txt
        -s|--sort) _SORT=1; ;;
        -l|--list) _LIST=1 _LIST_DATA=$2; shift ;;
        -h|--help) usage ;; 
        *) _DEFAULT=1 ;;
    esac
    shift
done

# Options
if [[ "$_RESOLVER" -eq "1" ]]; then
    _DNS="$_RESOLVER_DATA"
else
    _DNS="1.1.1.1"
fi

if [[ "$_DOMAIN" -eq "1" ]]; then
    _TARGET="$_DOMAIN_DATA"
else
    _TARGET="lab.sys-adm.in"
fi

# Spinner
# ---------------------------------------------------\
function _spinner() {
 
    case $1 in
        start)
            let column=$(tput cols)-${#2}-120
            echo -ne ${2}
            printf "%${column}s"

            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.1}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "DONE"
            else
                echo -en "FAIL"
            fi
            echo -e "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    _spinner "start" "${1}" &
    _sp_pid=$!
    disown
}

function stop_spinner {
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

function spin {
	start_spinner "Iterating ${1}"
	  $2 > /dev/null 2>&1
	  stop_spinner $?
}

# Single test
singleTest() {

	for i in `seq 1 $1`; do 
		result=`dig @$_DNS $_TARGET | awk '/Query time:/ {print " "$4}'`
		echo -e "Example time (ms):$result from $_DNS to $_TARGET"
	done
	echo ''

}

# Digger routine
dig_ip() {
		
		for IP in `cat $_TARGETS`; do
		    time=`dig @$IP $site| awk '/Query time:/ {print " "$4}'`
		    IPtrans=`echo $IP|tr \. _`
		    eval `echo result$IPtrans=\"\\$result$IPtrans$time\"`
		done
}

# Statistic test
statisticsTest() {

	# Testing dig installed
	if ! command -v dig &> /dev/null
	then
	    echo -e "\nThe dig could not be found. Please install dig command!\nExit. Bye.\n"
	    exit
	fi

	echo ''; singleTest 1 # $_TESTS
	for i in `seq 1 $_TESTS`; do 
		spin $i 'dig_ip $i'
	done

	echo -e "\nResult statistics:\n"

	for IP in `cat $_TARGETS`; do
	  IPtrans=`echo $IP|tr \. _`
	  printf "%-15s " "$IP"; echo -e `eval "echo \\$result$IPtrans"`|tr ' ' "\n"|awk '/.+/ {rt=$1; rec=rec+1; total=total+rt; if (minn>rt || minn==0) {minn=rt}; if (maxx<rt) {maxx=rt}; }
	             END{ if (rec==0) {ave=0} else {ave=total/rec}; printf "average %5i     min %5i     max %5i ms %2i responses\n", ave,minn,maxx,rec}'
	done
	echo ""

}

sorting() {
    cat default.txt | uniq | sort > sorted.txt; mv sorted.txt default.txt;
}

exit_success() {
    exit 0
}

exit_err() {
    exit 1
}

# Actions
# ---------------------------------------------------\

# Customs
if [[ "$_SORT" -eq "1" ]]; then 

    if [[ "$_LIST" -eq "1" ]]; then 

        if [[ -f "$_LIST_DATA" ]]; then
            echo "Sorting $_LIST_DATA..."
            sorting
            echo "Done."
        else
            echo "File $_LIST_DATA does not exists. Exit."
            exit_err
        fi

        
    else
        echo "Sorting default.txt..."
        sorting
        echo "Done."
    fi

    exit_success
fi

if [[ "$_ADD" -eq "1" ]]; then

    if grep -R "$_ADD_DATA" "$_DEFAULT_LIST"
    then
        echo "IP already exist"
    else
        echo "Adding $_ADD_DATA to $_DEFAULT_LIST..."
        echo -e "$_ADD_DATA" >> $_DEFAULT_LIST

        if [[ "$_SORT" -eq "1" ]]; then sorting; fi
    fi
    
    exit_success
fi

# Operational

# If parameters / arguments is empty
if [ ! -f "$_TARGETS" ] || ! echo "$_TESTS"|egrep -q "[0-9]+" ; then
    cd $SCRIPT_PATH; ./$SCRIPT_NAME $_DEFAULT_LIST 1
    usage
fi

# statisticsTest


if [[ "$_DEFAULT" -eq "1" ]]; then
    
    echo "Starting..."
    statisticsTest
    exit_success

fi


