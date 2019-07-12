#!/bin/bash
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

# TODO: improve comments
# TODO: refactor so it's a bit more readable
# TODO: standardize colors so we don't have random ANSI sequences laying around
# TODO: make standard color white

# ---------------- GET POSTS ---------------- #
# $1 is START_INDEX
# $2 is END_INDEX

LIST=""
get_posts() {
	echo -ne "${3:-"Getting more posts...  "}"
	_get_posts $1 $2 & \
	while [ "$(ps a | awk '{print $1}' | grep $!)" ] ; do for X in '-' '/' '|' '\' ; do echo -en "\b$X" ; sleep 0.1 ; done ; done
}
_get_posts() {
	for i in `seq $1 $2` ; do
		# Get post info
		POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[$i]}".json?print=pretty`
		TITLE=`echo $POST | jq .title`
		DESCENDANTS=`echo $POST | jq .descendants`
		AUTHOR=`echo $POST | jq .by`
		SCORE=`echo $POST | jq .score`
		TIME=`echo $POST | jq .time`
		TIME=$(( `date +%s` - $TIME ))

		# Append to display list
		LIST="$LIST`echo -ne "$(( $i + 1 )). "`"
		LIST="$LIST`clean_text $TITLE`\n"
		LIST="$LIST   `clean_text $SCORE` points by `clean_text $AUTHOR` `clean_text $TIME` seconds ago | `clean_text $DESCENDANTS` comments\n"
		# TODO: fix time so it's actually readable
	done
	echo -ne "\033[2K\033[E"
	echo -ne "$LIST"
	LIST=""
}
# ---------------- END GET POSTS ---------------- #

# ---------------- GET THREAD ---------------- #
get_thread() {
	POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[(( $ID - 1 ))]}".json?print=pretty`
	CHILDREN=( `echo $POST | jq .kids[]` )
	TITLE=`echo $POST | jq .title`
	DESCENDANTS=`echo $POST | jq .descendants`
	AUTHOR=`echo $POST | jq .by`
	SCORE=`echo $POST | jq .score`
	TIME=`echo $POST | jq .time`
	TIME=$(( `date +%s` - $TIME ))

	echo -e "\033[92m`clean_text $TITLE`\033[0m"
	echo "`clean_text $SCORE` points by `clean_text $AUTHOR` `clean_text $TIME` seconds ago | `clean_text $DESCENDANTS` comments"
	_get_thread 0 "${CHILDREN[@]}"
	# TODO: add spinner here
}
_get_thread() {
	# TODO: add timestamp
	# TODO: limit number of comments
	NUM=$1
	shift
	for CHILD in $@ ; do
		COMMENT=`curl -s https://hacker-news.firebaseio.com/v0/item/$CHILD.json?print=pretty`
		INDENT=""
		for _ in `seq 0 $NUM` ; do
			INDENT="$INDENT    "
		done
		AUTHOR=`echo "$COMMENT" | jq .by`
		SCORE=`echo "$COMMENT" | jq .score`
		echo -e "$INDENT\033[96m`clean_text $AUTHOR`\033[0m:"
		COMMENT_TEXT=`echo "$COMMENT" | jq .text`
		clean_text $COMMENT_TEXT | fold -w 80 -s | sed "s/^/$INDENT/"
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
	# TODO: clean text more
	# extract links from <a> tags
	CONTENT=`echo "$@" | sed \
	-e 's/^"//' \
	-e 's/"$//' \
	-e 's/&gt;/>/g' \
	-e "s/&#x27;/'/g" \
	-e 's/&quot;/"/g' \
	-e 's/<p>/\\\n\\\n/g' \
	-e 's/<br>/\\\n\\\n/g'`
	echo -e "$CONTENT"
}

START_INDEX=0
END_INDEX=$(( $START_INDEX + 9 ))
get_posts $START_INDEX $END_INDEX "Getting posts...  "

# ---------------- MAIN LOOP ---------------- #
PROMPT="\033[2K\033[E> "
while : ; do
	echo -ne "$PROMPT"
	IFS='' read KEY

	# if KEY is a number
	[ -n "$KEY" ] && [ "$KEY" -eq "$KEY" ] 2>/dev/null
	if [[ $? -eq 0 ]] ; then
		if [[ $KEY -lt 501  && $KEY -gt 0 ]] ; then
			POST=`curl -s https://hacker-news.firebaseio.com/v0/item/"${POSTS[(( $KEY - 1 ))]}".json?print=pretty`
			DESCENDANTS=`echo $POST | jq .descendants`
			AUTHOR=`echo $POST | jq .by`
			SCORE=`echo $POST | jq .score`
			TIME=`echo $POST | jq .time`
			TIME=$(( `date +%s` - $TIME ))

			echo -ne "${KEY}. "
			echo "$(clean_text `echo $POST | jq .title`)"
			echo "   `clean_text $SCORE` points by `clean_text $AUTHOR` `clean_text $TIME` seconds ago | `clean_text $DESCENDANTS` comments"
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
				echo "Post index must be between 1 and 500"
				continue
			fi
			get_thread $ID
			;;
		b|back)
			get_posts $START_INDEX $END_INDEX
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
				get_posts $START_INDEX $END_INDEX
			else
				echo "Post index must be between 1 and 500"
			fi
			;;
		h|help|list)
			echo "Available commands:"
			echo "  help      - show this help menu"
			echo "  read <ID> - open the comment thread for post ID"
			echo "  <ID>      - get the title for post ID"
			echo "  back      - show the previous list of stories again"
			echo "  more      - show the next 10 posts (up to 500)"
			echo "  less      - show the previous 10 posts"
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
