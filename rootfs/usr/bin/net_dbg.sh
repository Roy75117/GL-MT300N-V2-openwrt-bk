export_ipt(){
	iptables-save
	echo
	ipset sa
	if [ -n "$(which fw4)" ]; then
		nft -s list ruleset >nft
	fi
}

export_ipr(){
	ip rule

	echo
	echo "table 1:"
	ip route show table 1

	echo
	echo "table 2:"
	ip route show table 2

	echo
	echo "table 3:"
	ip route show table 3

	echo
	echo "table 4:"
	ip route show table 4

	echo
	echo "table 31:"
	ip route show table 31

	echo
	echo "table 51:"
	ip route show table 51

	echo
	echo "table 52:"
	ip route show table 52

	echo
	echo "table 53:"
	ip route show table 53

	echo
	echo "table 55:"
	ip route show table 55

	echo
	echo "table 128:"
	ip route show table 128

	echo
	echo "table local:"
	ip route show table local

	echo
	echo "table main:"
	ip route show table main
}

export_ipt6(){
	ip6tables-save
}

export_ipr6(){
	ip -6 rule >ipr6

	echo 
	echo "table 5:" 
	ip -6 route show table 5 

	echo 
	echo "table 6:" 
	ip -6 route show table 6 

	echo 
	echo "table 7:" 
	ip -6 route show table 7 

	echo 
	echo "table 8:" 
	ip -6 route show table 8 

	echo 
	echo "route:" 
	ip -6 route show 
}

export_wg(){
wg | sed -e 's/public key: .*/public key: *****/' \
    -e 's/peer: .*/peer: *****/' \
    -e 's/endpoint: .*/endpoint: *****/' \
    -e 's/listening port: .*/listening port: *****/'
}

export_ipt >ipt
export_ipr >ipr
export_ipt6 >ipt6
export_ipr6 >ipr6
export_wg >wg
