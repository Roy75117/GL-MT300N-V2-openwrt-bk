PS1='\[\033[01;31m\]\t\[\033[00m\][$?]\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w \$\[\033[00m\] '
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -lh'
alias cls='clear'
#alias ps='ps -ef'
alias port_check='sudo lsof -i -P -n | grep LISTEN'
alias opkg_upgrade="opkg list-upgradable | cut -f 1 -d ' ' | xargs -r opkg upgrade"
