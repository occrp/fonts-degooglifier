#!/bin/bash

#
# Font DeGooglifier
#
# $1, ... - CSS files or URLs to de-googlify
#

#
# helper function -- getting a CSS file name
# from a fonts.googleapis.com URL
#
# $1 -- URL to handle
function get_local_filename_from_url() {
    echo -n "$1" | sed -r -e 's%https://fonts.googleapis.com/css\?family=%%' -e 's/&(amp;)?/__/' | tr '|:+,=' '_-'
    echo '.css'
}

#
# in a local file replace '@import url()' lines
# that lead to fonts.googleapis.com
# with locally downloaded CSS files
# 
# $1 -- font directory to dump the fonts to
# $2 -- the CSS file to degooglify
function degooglify_css_file_import() {

    # source CSS file
    local CSS_IMPORT_SRC="$2"
    
    # destination CSS file
    local CSS_IMPORT_DEST="${CSS_IMPORT_SRC/.css/.degooglified.css}"
    
    # destination directory
    # assuming it exists and is writeable
    local FONT_DIR="$1"
    
    # inform
    echo "+-- de-googlifying import statements: $CSS_IMPORT_SRC"
    echo "    +-- destination font directory : $FONT_DIR/"
    echo "    +-- destination CSS file       : $CSS_IMPORT_DEST"
    
    # make a copy to later work on
    # (unless it exists already)
    if [ ! -f "$CSS_IMPORT_DEST" ]; then
        if ! cp "$CSS_IMPORT_SRC" "$CSS_IMPORT_DEST"; then
            echo "ERROR: unable to create the destination CSS file: '$CSS_IMPORT_DEST'"
            exit 1
        fi
    else
        echo
        echo "NOTICE: destination CSS file already exists: '$CSS_IMPORT_DEST'"
        echo "NOTICE: (this will not work great if the source or destination)"
        echo "NOTICE: (files were changed by external programs              )"
        echo
    fi
    [ ! -r "$CSS_IMPORT_DEST" ] && echo "ERROR: destination CSS file is not readable: '$CSS_IMPORT_DEST'" && exit 1
    [ ! -w "$CSS_IMPORT_DEST" ] && echo "ERROR: destination CSS file is not writable: '$CSS_IMPORT_DEST'" && exit 1
    
    
    # we need to split fields on newlines
    OLDIFS="$IFS"
    IFS=$'\n'
   
    # first, get the @import statements
    # that fetch remote fonts.googleapis.com CSS files
    for CSS_IMPORT_LINE in $( egrep "^[[:space:]]*@import url\('?https://fonts.googleapis.com/css" "$CSS_IMPORT_SRC" ); do
        
        # inform
        echo "    +-- working with: $CSS_IMPORT_LINE"
        
        # get the URL
        # this sed expression will get the *last* occurence of the 'url()' stanza
        local CSS_IMPORT_URL="$( echo "$CSS_IMPORT_LINE" | sed -r -e "s/.*url\('?([^')]+)'?\).*/\1/g" )"
        echo "        +-- CSS remote URL: $CSS_IMPORT_URL"
        
        # get the local filename
        local CSS_IMPORT_LOCAL="$( get_local_filename_from_url "$CSS_IMPORT_URL" )"
        echo "        +-- local filename: $CSS_IMPORT_LOCAL"
        
        # fetch and degooglify that file, why not
        degooglify_css_url "$FONT_DIR" "$CSS_IMPORT_URL"
        
        # replace the URL with the local file name
        # adding '.degooglified' before '.css'
        # since we want to use the degooglified version of that file 
        sed -i -e "s%$CSS_IMPORT_URL%${CSS_IMPORT_LOCAL/.css/.degooglified.css}%" "$CSS_IMPORT_DEST"
    done
    
    # revert to the original IFS
    IFS="$OLDIFS"
}

#
# the actual workhorse
# 
# handling the 'src:' stanzas
# downloading the fonts and replacing 'url()' sources with locally downloaded files
# 
# $1 -- font directory to dump the fonts to
# $2 -- the CSS file to degooglify
function degooglify_css_file_src() {

    # source CSS file
    local CSS_SRC="$2"
    
    # destination CSS file
    local CSS_DEST="${CSS_SRC/.css/.degooglified.css}"
    
    # destination directory
    # assuming it exists and is writeable
    local FONT_DIR="$1"
    
    # inform
    echo "+-- de-googlifying src lines: $CSS_SRC"
    echo "    +-- destination font directory : $FONT_DIR/"
    echo "    +-- destination CSS file       : $CSS_DEST"
    
    # make a copy to later work on
    # (unless it exists already)
    if [ ! -f "$CSS_DEST" ]; then
        if ! cp "$CSS_SRC" "$CSS_DEST"; then
            echo "ERROR: unable to create the destination CSS file: '$CSS_DEST'"
            exit 1
        fi
    else
        echo
        echo "NOTICE: destination CSS file already exists: '$CSS_DEST'"
        echo "NOTICE: (this will not work great if the source or destination)"
        echo "NOTICE: (files were changed by external programs              )"
        echo
    fi
    [ ! -r "$CSS_DEST" ] && echo "ERROR: destination CSS file is not readable: '$CSS_DEST'" && exit 1
    [ ! -w "$CSS_DEST" ] && echo "ERROR: destination CSS file is not writable: '$CSS_DEST'" && exit 1
    
    
    # we need to split fields on newlines
    OLDIFS="$IFS"
    IFS=$'\n'
   
    # first, get the URLs of fonts
    #
    # assumptions:
    # - there is only one instance of each FONT_URL in the whole file
    for FONT_SRC_LINE in $( egrep '^[[:space:]]*src' "$CSS_SRC" ); do
    
        # inform
        echo "    +-- working with: $FONT_SRC_LINE"
        
        # get the URL
        # this sed expression will get the *last* occurence of the 'url()' stanza
        local FONT_URL="$( echo "$FONT_SRC_LINE" | sed -r -e "s/.*url\('?([^')]+)'?\).*/\1/g" )"
        echo "        +-- URL: $FONT_URL"
        
        # check if the URL is a fonts.gstatic.com one
        if [[ $FONT_URL != "https://fonts.gstatic.com"* ]]; then
            echo "        +-- not a Google font URL, ignoring..."
            continue
        fi
        
        # we also need the extension
        local FONT_EXT="${FONT_URL##*.}"
        
        # get the local name
        # this sed expression will get the *last* occurence of the 'local()' stanza
        # tr removes spaces just in case
        local FONT_NAME="$( echo "$FONT_SRC_LINE" | sed -r -e "s/.*local\('?([^')]+)'?\).*/\1/g" | tr -d ' ' )"
        
        # download the font
        local FONT_FILE="$FONT_DIR/$FONT_NAME.$FONT_EXT"
        echo "        +-- target: $FONT_FILE"
        wget -nc --progress=dot -O "$FONT_FILE" "$FONT_URL"
        
        # replace the url in the source line in the file
        sed -i -e "s%$FONT_URL%$FONT_FILE%" "$CSS_DEST"
        
    done
    
    # revert to the original IFS
    IFS="$OLDIFS"
}


#
# handle a local file
#
# $1 -- font directory to dump the fonts to
# $2 -- the CSS file to degooglify
function degooglify_css_file () {
  
    # replace '@import url()' lines leading to fonts.googleapis.com
    # with locally downloaded CSS files
    degooglify_css_file_import "$1" "$2"
    
    # replace 'src:' lines leading to rempote resources
    # with locally downloaded fonts
    degooglify_css_file_src "$1" "$2"
}

#
# handle a CSS file available from fonts.googleapis.com
# 
# $1 -- font directory to dump the fonts to
# $2 -- URL
function degooglify_css_url() {
    
    # destination directory
    # assuming it exists and is writeable
    local FONT_DIR="$1"
    
    # remote CSS file
    local CSS_REMOTE="$2"
    
    # reality check -- is this a fonts.googleapis.com/css link?
    if [[ $CSS_REMOTE != "https://fonts.googleapis.com/css"* ]]; then
        echo "ERROR: supplied URL is not a link to fonts.googleapis.com: '$CSS_REMOTE'"
    fi
    
    # we're good, I guess
    # get the filename from the URL
    local CSS_LOCAL=$( get_local_filename_from_url "$CSS_REMOTE" )
    
    # inform
    echo "+-- downloading remote CSS:"
    echo "    +-- source URL       : $CSS_REMOTE"
    echo "    +-- destination file : $CSS_LOCAL"
    
    # download
    wget -nc --progress=dot -O "$CSS_LOCAL" "$CSS_REMOTE"
    
    # handle the downlaoded file
    degooglify_css_file "$FONT_DIR" "$CSS_LOCAL" || exit 1
}



# target directory
# TODO: make that configurable on the command line
TARGET_FONT_DIR="fonts/"
# remove the ending slash in case it's there
TARGET_FONT_DIR=${TARGET_FONT_DIR%/}

# reality checks
# making sure the destination directory exists and is readable and writeable
if [ ! -d "$TARGET_FONT_DIR" ]; then
    if ! mkdir -p "$TARGET_FONT_DIR"; then
        echo "ERROR: unable to create the destination font directory: '$TARGET_FONT_DIR'"
        exit 1
    fi
fi
[ ! -r "$TARGET_FONT_DIR" ] && echo "ERROR: destination font directory not readable: '$TARGET_FONT_DIR'" && exit 1
[ ! -w "$TARGET_FONT_DIR" ] && echo "ERROR: destination font directory not writeable: '$TARGET_FONT_DIR'" && exit 1

# do the magic
for SOURCE_OF_CSS in "$@"; do
    
    # are we dealing with a remote resource?
    # 
    # we're lowercasing here only since it's needed for the comparison
    # however, URLs are case-sensitive,
    # so we can't just go with the lowercase version everywhere
    if [[ $( echo "${SOURCE_OF_CSS:0:8}" | tr '[:upper:]' '[:lower:]' ) == "https://" ]]; then
        # yes we are! deal with it, then
        degooglify_css_url "$TARGET_FONT_DIR" "$SOURCE_OF_CSS"
    else
        # nope, all local
        degooglify_css_file "$TARGET_FONT_DIR" "$SOURCE_OF_CSS"
    fi
done
