#!/bin/bash

#
# Font DeGooglifier
#
# $1, ... - CSS files or URLs to de-googlify
#


#
# the actual workhorse
# 
# $1 -- font directory to dump the fonts to
# $2 -- the CSS file to degooglify
function degooglify_css() {

    # source CSS file
    CSS_SRC="$2"
    
    # destination CSS file
    CSS_DEST="${CSS_SRC/.css/.degooglified.css}"
    
    # make a copy to later work on
    cp "$CSS_SRC" "$CSS_DEST"|| ( echo "ERROR: unable to create the destination CSS file: '$CSS_DEST'" && exit 1 )
    
    # destination directory
    # assuming it exists and is writeable
    FONT_DIR="$1"
    
    # inform
    echo "+-- de-googlifying: $CSS_SRC"
    echo "    +-- destination font directory : $FONT_DIR/"
    echo "    +-- destination CSS file       : $CSS_DEST"
    
    # we need to split fields on newlines
    OLDIFS="$IFS"
    IFS=$'\n'
   
    # first, get the URLs of fonts
    #
    # assumptions:
    # - there is only one instance of each FONT_URL in the whole file
    for FONT_SRC_LINE in $( egrep '^[[:space:]]+src' "$CSS_SRC" ); do
    
        # inform
        echo "    +-- working with: $FONT_SRC_LINE"
        
        # get the URL
        # this sed expression will get the *last* occurence of the 'url()' stanza
        FONT_URL="$( echo "$FONT_SRC_LINE" | sed -r -e "s/.*url\('?([^')]+)'?\).*/\1/g" )"
        echo "        +-- URL: $FONT_URL"
        
        # we also need the extension
        FONT_EXT="${FONT_URL##*.}"
        
        # get the local name
        # this sed expression will get the *last* occurence of the 'local()' stanza
        # tr removes spaces just in case
        FONT_NAME="$( echo "$FONT_SRC_LINE" | sed -r -e "s/.*local\('?([^')]+)'?\).*/\1/g" | tr -d ' ' )"
        
        # download the font
        FONT_FILE="$FONT_DIR/$FONT_NAME.$FONT_EXT"
        echo "        +-- target: $FONT_FILE"
        wget -nc --progress=dot -O "$FONT_FILE" "$FONT_URL"
        
        # replace the url in the source line in the file
        sed -i -r -e "s%$FONT_URL%$FONT_FILE%" "$CSS_DEST"
        
    done
    
    # revert to the original IFS
    IFS="$OLDIFS"
}


#
# handle a CSS file available from fonts.googleapis.com
# 
# $1 -- font directory to dump the fonts to
# $2 -- URL
function degooglify_remote() {
    
    # destination directory
    # assuming it exists and is writeable
    FONT_DIR="$1"
    
    # remote CSS file
    CSS_REMOTE="$2"
    
    # reality check -- is this a fonts.googleapis.com/css link?
    if [[ $CSS_REMOTE != "https://fonts.googleapis.com/css"* ]]; then
        echo "ERROR: supplied URL is not a link to fonts.googleapis.com: '$CSS_REMOTE'"
    fi
    
    # we're good, I guess
    # get the filename from the URL
    CSS_LOCAL="$( echo "$CSS_REMOTE" | sed -r -e 's%https://fonts.googleapis.com/css\?family=%%' -e 's/&amp;/__/' | tr '|:+,=' '_-' ).css"
    
    # inform
    echo "+-- downloading remote CSS:"
    echo "    +-- source URL       : $CSS_REMOTE"
    echo "    +-- destination file : $CSS_LOCAL"
    
    # download
    wget -nc --progress=dot -O "$CSS_LOCAL" "$CSS_REMOTE"
    
    # handle the downlaoded file
    degooglify_css "$FONT_DIR" "$CSS_LOCAL"
}



# target directory
# TODO: make that configurable on the command line
TARGET_FONT_DIR="fonts/"
# remove the ending slash in case it's there
TARGET_FONT_DIR=${TARGET_FONT_DIR%/}

# reality checks
# making sure the destination directory exists and is readable and writeable
[ -d "$TARGET_FONT_DIR" ] || mkdir -p "$TARGET_FONT_DIR" || ( echo "ERROR: unable to create the destination font directory: '$TARGET_FONT_DIR'" && exit 1 )
[ -r "$TARGET_FONT_DIR" ] || ( echo "ERROR: destination font directory not readable: '$TARGET_FONT_DIR'" && exit 1 )
[ -w "$TARGET_FONT_DIR" ] || ( echo "ERROR: destination font directory not writeable: '$TARGET_FONT_DIR'" && exit 1 )

# do the magic
for SOURCE_OF_CSS in "$@"; do
    
    # are we dealing with a remote resource?
    if [[ ${SOURCE_OF_CSS,,} == "https://"* ]]; then
        # yes we are! deal with it, then
        degooglify_remote "$TARGET_FONT_DIR" "$SOURCE_OF_CSS"
    else
        # nope, all local
        degooglify_css "$TARGET_FONT_DIR" "$SOURCE_OF_CSS"
    fi
done
