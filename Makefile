rsync-snail: #only used for local dev, do not use on server
	rsync -urltv --delete --exclude-from='rsyncignore.txt' -e ssh . snail:~/work/interface_debug

rsync-vlab: #only used for local dev, do not use on server
	rsync -urltv --delete --exclude-from='rsyncignore.txt' -e ssh . vlab:~/work/interface_debug

rsync: rsync-snail