#!/bin/bash

#
# Font DeGooglifier
#

#
# $1, ... - CSS files to de-googlify
#


#
# the actual workhorse
# 
# $1 -- the CSS file to degooglify
# $2 -- font directory to dump the fonts to
function degooglify_css() {

    # source CSS file
    CSS_SRC="$1"
    
    # destination CSS file
    CSS_DEST="${CSS_SRC/.css/.degooglified.css}"
    
    # make a copy to later work on
    cp "$CSS_SRC" "$CSS_DEST"|| ( echo "ERROR: unable to create the destination CSS file: '$CSS_DEST'" && exit 1 )
    
    # destination directory
    # assuming it exists and is writeable
    FONT_DIR="$2"
    
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
for CSS_FILE in "$@"; do
    degooglify_css "$CSS_FILE" "$TARGET_FONT_DIR"
done
