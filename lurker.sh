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
LIST=""
get_posts() {
	# Handle spinner and call function to get posts
	# $1 is START_INDEX
	# $2 is END_INDEX
	# $3 is loading text (optional)

	echo -ne "${3:-"Fetching more posts...  "}"
	_get_posts $1 $2 & \
	while [ "$(ps a | awk '{print $1}' | grep $!)" ] ; do for X in '-' '/' '|' '\' ; do echo -en "\b$X" ; sleep 0.1 ; done ; done
}
_get_posts() {
	# get posts between START_INDEX and END_INDEX
	# $1 is START_INDEX
	# $2 is END_INDEX

	for i in `seq $1 $2` ; do
		# get post info
		POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[$i]}".json?print=pretty`
		TITLE=`echo $POST | jq -r .title`
		DESCENDANTS=`echo $POST | jq -r .descendants`
		AUTHOR=`echo $POST | jq -r .by`
		SCORE=`echo $POST | jq -r .score`
		TIME=`echo $POST | jq -r .time`
		TIME=$(( `date +%s` - $TIME ))
		TIME_TEXT=`clean_time $TIME`
		URL=`echo $POST | jq -r .url`
		URL=`echo $URL | awk -F[/:] '{print $4}'`

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

# ---------------- GET THREAD ---------------- #
get_thread() {
	# Handle spinner and call function to get posts
	# $1 is the post ID

	# get post info
	POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[(( $1 - 1 ))]}".json?print=pretty`
	CHILDREN=( )
	if echo "$POST" | jq -r -e 'has("kids")' > /dev/null; then
			CHILDREN=( `echo $POST | jq -r .kids[]` )
	fi
	TITLE=`echo $POST | jq -r .title`
	DESCENDANTS=`echo $POST | jq -r .descendants`
	AUTHOR=`echo $POST | jq -r .by`
	SCORE=`echo $POST | jq -r .score`
	TIME=`echo $POST | jq -r .time`
	TIME=$(( `date +%s` - $TIME ))
	TIME_TEXT=`clean_time $TIME`
	URL=`echo $POST | jq -r .url`
	URL=`echo $URL | awk -F[/:] '{print $4}'`

	# display post header info
	echo "$(green `clean_text $TITLE`) $(pink "($URL)")"
	echo "$(blue `clean_text $SCORE` points) $(white by) $(yellow `clean_text $AUTHOR`) $(white `clean_text $TIME_TEXT` "|") $(teal `clean_text $DESCENDANTS` comments)"

	# start recursive comment tree traversal for thread
	if [[ $DESCENDANTS -gt 0 ]] ; then
		echo -ne "${3:-"Fetching $DESCENDANTS comments...  "}"
		LIST=""
		_get_thread 0 "${CHILDREN[@]}" & \
		while [ "$(ps a | awk '{print $1}' | grep $!)" ] ; do for X in '-' '/' '|' '\' ; do echo -en "\b$X" ; sleep 0.1 ; done ; done
	fi
}
_get_thread() {
	# Intermediate function to handle recursion cleanly
	# $1 is the depth of recursion for __get_thread
	# $2 is the list of children to traverse for __get_thread

	LIST=`__get_thread 0 "${CHILDREN[@]}"`
	echo -ne "\033[2K\033[E"
	echo -e "$LIST"
	LIST=""
}
__get_thread() {
	# get comments for thread
	# $1 is the depth of our recursion
	# $2 is the list of children to traverse

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

		# get comment information
		AUTHOR=`echo "$COMMENT" | jq -r .by`
		COMMENT_TEXT=`echo "$COMMENT" | jq -r .text`
		TIME=`echo "$COMMENT" | jq -r .time`
		TIME=$(( `date +%s` - $TIME ))
		TIME_TEXT=`clean_time $TIME`
		DELETED=`echo "$COMMENT" | jq -r .deleted`
		DEAD=`echo "$COMMENT" | jq -r .dead`

		# skip if comment has been deleted
		if [[ "$DELETED" == "true" || "$DEAD" == "true" ]] ; then
			continue
		fi

		# display comment information
		echo "$INDENT$(teal "`clean_text $AUTHOR`") $(white "|") $(teal "$TIME_TEXT:")"
		clean_text $COMMENT_TEXT | fold -w 100 -s | sed "s/^/$INDENT/"

		# calculate children to continue traversal
		CHILDREN=( )
		if echo "$COMMENT" | jq -r -e 'has("kids")' > /dev/null; then
			CHILDREN=( `echo $COMMENT | jq -r .kids[]` )
		fi
		if [[ ${#CHILDREN[@]} -gt 0 ]] ; then
			__get_thread $(( $NUM + 1 )) "${CHILDREN[@]}"
		fi
	done
}
# ---------------- END GET THREAD ---------------- #

# ---------------- CLEAN DATA ---------------- #
clean_time() {
	# clean time into a human readable format
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

clean_text() {
	# clean text into terminal friendly format
	# $@ is the text to clean

	CONTENT=$(echo "$@" | sed \
	-e 's/&gt;/>/g' \
	-e "s/&#x27;/'/g" \
	-e 's/&quot;/"/g' \
	-e 's/<i>/_/g' \
	-e 's;</i>;_;g' \
	-e 's/<b>/**/g' \
	-e 's;</b>;**;g' \
	-e 's/<strong>/**/g' \
	-e 's;</strong>;**;g' \
	-e 's~&#x2F;~/~g' \
	-e 's~<a .*\(href=\\"[^\\"]*\).*</a>~\1~g' \
	-e 's~href=\\"~~g' \
	-e 's~<a .*\(href="[^"]*\).*</a>~\1~g' \
	-e 's~href="~~g')
	if [[ `uname -s` == "Darwin" ]] ; then
		CONTENT=$(echo "$CONTENT" | sed \
		-e 's/<p>/\\\n\\\n/g' \
		-e 's/<br>/\\\n\\\n/g')
	else
		CONTENT=$(echo "$CONTENT" | sed \
		-e 's/<p>/\n\n/g' \
		-e 's/<br>/\n\n/g')
	fi
	echo -e "$CONTENT"
}
# ---------------- END CLEAN DATA ---------------- #

# ---------------- MAIN LOOP ---------------- #
# MAIN LOOP DESIGN:
#  1. Display prompt, receive keyboard input
#  2. Parse input, handle command

START_INDEX=0
END_INDEX=$(( $START_INDEX + 9 ))
get_posts $START_INDEX $END_INDEX "Fetching posts...  "
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
			TITLE=`echo $POST | jq -r .title`
			DESCENDANTS=`echo $POST | jq -r .descendants`
			AUTHOR=`echo $POST | jq -r .by`
			SCORE=`echo $POST | jq -r .score`
			TIME=`echo $POST | jq -r .time`
			TIME=$(( `date +%s` - $TIME ))
			TIME_TEXT=`clean_time $TIME`
			URL=`echo $POST | jq -r .url`
			URL=`echo $URL | awk -F[/:] '{print $4}'`

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
			if [[ $ID -lt 1 || $ID -gt 500 ]] ; then
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
			URL=`echo $POST | jq -r .url`
			if [[ `uname -s` == "Darwin" ]] ; then
				open `echo $URL | sed -e 's/"//g'` 
			else
				echo "Sorry, can't open a web browser for this operating system. Here's the link you'd like to open:"
				echo "  $URL" | sed -e 's/"//g'
			fi
			;;
		clear)
			clear
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
			echo "  clear     - clear the screen"
			echo "  exit      - quit Lurker"
			;;
		q|quit|exit|done)
			exit 0
			;;
		*)
			if [[ "$KEY" == "" ]] ; then
				DISP=""
			else
				KEY=( $KEY )
				DISP="'${KEY[0]}'"
			fi
			echo "Unknown command $DISP"
			echo "Type 'help' for command list"
			;;
	esac
done
# ---------------- END MAIN LOOP ---------------- #
