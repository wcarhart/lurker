#!/bin/bash

command -v jq > /dev/null 2>&1
if [[ $? -ne 0 ]] ; then
	echo "lurker: err: jq is not installed"
	echo "  lurker uses 'jq' to process Hacker News API responses"
	echo "  Please install jq by using one of the following (or similar), depending on your system:"
	echo "   - 'brew install jq'"
	echo "   - 'yum install jq'"
	echo "   - 'apt-get install jq'"
	exit 1
fi

echo '.____                  __                 '
echo '|    |    __ _________|  | __ ___________ '
echo '|    |   |  |  \_  __ \  |/ // __ \_  __ \'
echo '|    |___|  |  /|  | \/    <\  ___/|  | \/'
echo '|_______ \____/ |__|  |__|_ \\___  >__|   '
echo '        \/                 \/    \/       '

# get master list of posts (500 total)
POSTS=`curl -s https://hacker-news.firebaseio.com/v0/topstories.json`
POSTS="${POSTS//[/}"
POSTS="${POSTS//]/}"
POSTS=( ${POSTS//,/ } )

# ---------------- COLORS ---------------- #
COLORS=1
if [[ `tput colors` -eq 0 ]] ; then
	COLORS=0
fi
gray() {
	grey $@
}
grey() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[90m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
red() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[91m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
green() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[92m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
yellow() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[93m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
blue() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[94m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
pink() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[95m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
teal() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[96m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
white() {
	if [[ $COLORS -eq 1 ]] ; then
		echo -ne "\033[97m$@\033[0m"
	else
		echo -ne "$@"
	fi
}
# ---------------- END COLORS ---------------- #

# ---------------- GET POSTS ---------------- #
# $1 is START_INDEX
# $2 is END_INDEX
# $3 is loading text (optional)

LIST=""
get_posts() {
	echo -ne "${3:-"Getting more posts...  "}"
	_get_posts $1 $2 & \
	while [ "$(ps a | awk '{print $1}' | grep $!)" ] ; do for X in '-' '/' '|' '\' ; do echo -en "\b$X" ; sleep 0.1 ; done ; done
}
_get_posts() {
	for i in `seq $1 $2` ; do
		# get post info
		POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[$i]}".json?print=pretty`
		TITLE=`echo $POST | jq .title`
		DESCENDANTS=`echo $POST | jq .descendants`
		AUTHOR=`echo $POST | jq .by`
		SCORE=`echo $POST | jq .score`
		TIME=`echo $POST | jq .time`
		TIME=$(( `date +%s` - $TIME ))
		URL=`echo $POST | jq .url`
		URL=`echo $URL | awk -F[/:] '{print $4}'`
		TIME_TEXT=`cleanse_time $TIME`

		# append to display list
		LIST="$LIST`echo -ne "$(( $i + 1 )). "`"
		LIST="$LIST$(green `clean_text $TITLE`) $(pink "($URL)")\n"
		LIST="$LIST   $(blue `clean_text $SCORE` points) $(white by) $(yellow `clean_text $AUTHOR`) $(white `clean_text $TIME_TEXT` "|") $(teal `clean_text $DESCENDANTS` comments)\n"
	done
	echo -ne "\033[2K\033[E"
	echo -ne "$LIST"
	LIST=""
}
# ---------------- END GET POSTS ---------------- #

cleanse_time() {
	# $1 is the time elapsed in seconds
	if [[ $TIME -lt 60 ]] ; then
		if [[ $TIME -eq 1 ]] ; then
			TIME_TEXT="$TIME second ago"
		else
			TIME_TEXT="$TIME seconds ago"
		fi
	elif [[ $TIME -ge 60 && $TIME -lt 3600 ]] ; then
		TIME=$(( $TIME / 60 ))
		if [[ $TIME -eq 1 ]] ; then
			TIME_TEXT="$TIME minute ago"
		else
			TIME_TEXT="$TIME minutes ago"
		fi
	elif [[ $TIME -ge 3600 && $TIME -lt 86400 ]]; then
		TIME=$(( $TIME / 3600 ))
		if [[ $TIME -eq 1 ]] ; then
			TIME_TEXT="$TIME hour ago"
		else
			TIME_TEXT="$TIME hours ago"
		fi
	else
		TIME=$(( $TIME / 86400 ))
		if [[ $TIME -eq 1 ]] ; then
			TIME_TEXT="$TIME day ago"
		else
			TIME_TEXT="$TIME days ago"
		fi
	fi
	echo $TIME_TEXT
}

# ---------------- GET THREAD ---------------- #
get_thread() {
	# $1 is the post ID

	# get post info
	POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[(( $1 - 1 ))]}".json?print=pretty`
	CHILDREN=( )
	if echo "$POST" | jq -e 'has("kids")' > /dev/null; then
			CHILDREN=( `echo $POST | jq .kids[]` )
	fi
	TITLE=`echo $POST | jq .title`
	DESCENDANTS=`echo $POST | jq .descendants`
	AUTHOR=`echo $POST | jq .by`
	SCORE=`echo $POST | jq .score`
	TIME=`echo $POST | jq .time`
	TIME=$(( `date +%s` - $TIME ))
	URL=`echo $POST | jq .url`
	URL=`echo $URL | awk -F[/:] '{print $4}'`
	TIME_TEXT=`cleanse_time $TIME`

	# display post header info
	echo "$(green `clean_text $TITLE`) $(pink "($URL)")"
	echo "$(blue `clean_text $SCORE` points) $(white by) $(yellow `clean_text $AUTHOR`) $(white `clean_text $TIME_TEXT` "|") $(teal `clean_text $DESCENDANTS` comments)"

	# start recursive comment tree traversal for thread
	_get_thread 0 "${CHILDREN[@]}"
	# TODO: add spinner here
}
_get_thread() {
	# $1 is the depth of our recursion
	# $2 is the list of children to traverse

	# TODO: add timestamp
	# TODO: limit number of comments
	# TODO: make comments default to white
	local NUM=$1
	shift
	for CHILD in $@ ; do
		# get comment info
		COMMENT=`curl -s https://hacker-news.firebaseio.com/v0/item/$CHILD.json?print=pretty`
		
		# calculate indent
		INDENT=""
		for _ in `seq 0 $NUM` ; do
			INDENT="$INDENT    "
		done

		# print comment and it's author
		AUTHOR=`echo "$COMMENT" | jq .by`
		COMMENT_TEXT=`echo "$COMMENT" | jq .text`
		echo "$INDENT$(teal `clean_text $AUTHOR`:)"
		clean_text $COMMENT_TEXT | fold -w 100 -s | sed "s/^/$INDENT/"

		# calculate children to continue traversal
		CHILDREN=( )
		if echo "$COMMENT" | jq -e 'has("kids")' > /dev/null; then
			CHILDREN=( `echo $COMMENT | jq .kids[]` )
		fi
		if [[ ${#CHILDREN[@]} -gt 0 ]] ; then
			_get_thread $(( $NUM + 1 )) "${CHILDREN[@]}"
		fi
	done
}
# ---------------- END GET THREAD ---------------- #

clean_text() {
	CONTENT=$(echo "$@" | sed \
	-e 's/^"//' \
	-e 's/"$//' \
	-e 's/&gt;/>/g' \
	-e "s/&#x27;/'/g" \
	-e 's/&quot;/"/g' \
	-e 's/<p>/\\\n\\\n/g' \
	-e 's/<br>/\\\n\\\n/g' \
	-e 's/<i>/_/g' \
	-e 's;</i>;_;g' \
	-e 's/<b>/**/g' \
	-e 's;</b>;**;g' \
	-e 's/<strong>/**/g' \
	-e 's;</strong>;**;g' \
	-e 's~&#x2F;~/~g' \
	-e 's~<a .*\(href=\\"[^\\"]*\).*</a>~\1~g' \
	-e 's~href=\\"~~g')
	echo -e "$CONTENT"
}

# ---------------- MAIN LOOP ---------------- #
START_INDEX=0
END_INDEX=$(( $START_INDEX + 9 ))
get_posts $START_INDEX $END_INDEX "Getting posts...  "
PROMPT="\033[2K\033[E> "

while : ; do
	echo -ne "$PROMPT"
	IFS='' read KEY

	# if KEY is a number
	[ -n "$KEY" ] && [ "$KEY" -eq "$KEY" ] 2>/dev/null
	if [[ $? -eq 0 ]] ; then
		if [[ $KEY -lt 501  && $KEY -gt 0 ]] ; then
			# get post info
			POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[(( $KEY - 1 ))]}".json?print=pretty`
			TITLE=`echo $POST | jq .title`
			DESCENDANTS=`echo $POST | jq .descendants`
			AUTHOR=`echo $POST | jq .by`
			SCORE=`echo $POST | jq .score`
			TIME=`echo $POST | jq .time`
			TIME=$(( `date +%s` - $TIME ))
			URL=`echo $POST | jq .url`
			URL=`echo $URL | awk -F[/:] '{print $4}'`
			TIME_TEXT=`cleanse_time $TIME`

			# display info
			echo -ne "${KEY}. "
			echo "$(green `clean_text $TITLE`) $(pink "($URL)")"
			echo "   $(blue `clean_text $SCORE` points) $(white by) $(yellow `clean_text $AUTHOR`) $(white `clean_text $TIME_TEXT` "|") $(teal `clean_text $DESCENDANTS` comments)"
		else
			echo "Post index must be between 1 and 500"
		fi
		continue
	fi

	# if KEY is a command
	KEY=`echo "$KEY" | tr '[:upper:]' '[:lower:]'`
	case "$KEY" in
		read*)
			ID="${KEY#read*}"
			[ -n "$ID" ] && [ "$ID" -eq "$ID" ] 2>/dev/null
			if [[ $? -ne 0 ]] ; then
				echo "Post index must be a number"
				continue
			fi
			if [[ $ID -lt 0 || $ID -gt 500 ]] ; then
				echo "Post index must be between 1 and 500"
				continue
			fi
			get_thread $ID
			;;
		b|back)
			get_posts $START_INDEX $END_INDEX "Fetching posts again...  "
			;;
		m|more)
			START_INDEX=$(( $END_INDEX + 1 ))
			END_INDEX=$(( $START_INDEX + 9 ))
			get_posts $START_INDEX $END_INDEX
			;;
		l|less)
			if [[ $START_INDEX -gt 9 ]] ; then
				END_INDEX=$(( $START_INDEX - 1 ))
				START_INDEX=$(( $END_INDEX - 9 ))
				get_posts $START_INDEX $END_INDEX "Fetching previous posts...  "
			else
				echo "Post index must be between 1 and 500"
			fi
			;;
		open*)
			ID="${KEY#open*}"
			[ -n "$ID" ] && [ "$ID" -eq "$ID" ] 2>/dev/null
			if [[ $? -ne 0 ]] ; then
				echo "Post index must be a number"
				continue
			fi
			if [[ $ID -lt 0 || $ID -gt 500 ]] ; then
				echo "Post index must be between 1 and 500"
				continue
			fi
			POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[(( $ID - 1 ))]}".json?print=pretty`
			URL=`echo $POST | jq .url`
			if [[ `uname -s` == "Darwin" ]] ; then
				open `echo $URL | sed -e 's/"//g'` 
			else
				echo "Sorry, can't open a web browser for this operating system. Here's the link you'd like to open:"
				echo "  $URL" | sed -e 's/"//g'
			fi
			;;
		h|help|list)
			echo "Available commands:"
			echo "  help      - show this help menu"
			echo "  read <ID> - open the comment thread for post ID"
			echo "  open <ID> - open the URL for the post ID in your default browser"
			echo "  <ID>      - get the title for post ID"
			echo "  more      - show the next 10 posts (up to 500)"
			echo "  less      - show the previous 10 posts"
			echo "  back      - show the previous list of posts again"
			echo "  exit      - quit Lurker"
			;;
		q|quit|exit|done)
			exit 0
			;;
		*)
			if [[ "$KEY" == "" ]] ; then
				DISP=""
			else
				DISP="'$KEY'"
			fi
			echo "Unknown command $DISP"
			echo "Type 'help' for command list"
			;;
	esac
done
# ---------------- END MAIN LOOP ---------------- #
