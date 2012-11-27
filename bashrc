#!/bin/bash

# useful .bashrc functions... each one is explained in the comments


# usage: ama
# toggles between the QWERTY and dvorak keymaps in X. called "ama" because those
# are the only two keys that are in the same place on both keymaps. also sets
# the compose key
ama() {
  # check to make sure X is running
  [[ $DISPLAY ]] || return

  # if the current keymap is dvorak, set to qwerty
  if setxkbmap -print | grep -q 'dvorak'; then
    setxkbmap us -option compose:ralt

  # otherwise, set to dvorak
  else
    setxkbmap us -variant dvorak -option compose:ralt
  fi
}


# usage: dd_progress DD_OPTIONS
# a very primitive progress checking version of 'dd' using USR1
# TODO: create a more complex version that gives an actual progress bar
dd_progress() { 
  local dd_pid loop_pid

  # fork dd
  dd "$@" & dd_pid=$!

  # every minute, send USR1 to the dd process to get an update
  while sleep 1m; do
    kill -USR1 "$dd_pid"
  done & loop_pid=$! # fork the loop as well, so that it ends when dd does

  # wait for dd to finish. when it does, kill the loop as well
  wait "$dd_pid"
  kill "$loop_pid"
}


# usage: is_dir_in_path [DIR]
# basic function to check if a directory is in PATH. if DIR is not provided,
# uses the current working directory
is_dir_in_path() { 
  local path d t=${1:-$PWD}
  # trim trailing '/' from DIR, if it exists
  t=${1%/}

  # create an array from PATH, split on ':'s
  IFS=: read -rd '' -a path <<< "$PATH"
  # loop over each entry, and check it against DIR (after trimming any 
  # trailing '/'s)
  for d in "${path[@]}"; do
    # if it matches, return true
    [[ ${d%/} = "$t" ]] && return
  done

  # no match
  return 1
}


# usage: read_paste URL CURL_OPTIONS
# downloads URL with curl and opens with VISUAL, EDITOR, or vi, in that order.
# CURL_OPTIONS, if provided, are passed as additional arguments to curl, before
# URL
read_paste() {
  local tmp url=$1
  shift

  # create temp file and remove it when the function returns
  tmp=$(mktemp) || return
  trap 'rm -f "$tmp"' RETURN

  curl -# -o "$tmp" "$@" "$url" || return

  ${VISUAL:-${EDITOR:-vi}} "$tmp"
}


# usage: sprunge [OPTIONS] [FILE ...]
#
# Upload FILEs to sprunge.us. If FILE is not provided, or is '-', reads the
# standard input
#
#  Options:
#   -h, --help   Display this help and exit
sprunge() {
  local f err=0

  # check for --help
  while [[ $1 = -?* ]]; do
    case $1 in
      -h|--help)
        cat <<'EOF'
usage: sprunge [OPTIONS] [FILE ...]

Upload FILEs to sprunge.us. If FILE is not provided, or is '-', reads the
standard input

 Options:
  -h, --help   Display this help and exit
EOF
        return 0
        ;;
      --) shift; break;;
      *)
        printf 'invalid option: %s\n' "$1" >&2
        return 1
        ;;
    esac

    shift
  done

  # args provided, treat as files
  if (($#)); then
    # iterate over each FILE
    for f; do
      # if FILE is '-', use the standard input
      if [[ $f = - || $f = /dev/stdin ]]; then
        if (($# > 1)); then
          printf 'stdin: '
        fi
        curl -F 'sprunge=<-' http://sprunge.us || err=1

      # make sure it's a file or fifo and is readable
      elif [[ ( -f $f || -p $f ) && -r $f ]]; then
        if (($# > 1)); then
          printf '%s: ' "$f"
        fi
        curl -F 'sprunge=<-' http://sprunge.us <"$f" || err=1

      # unreadable or nonexistent file
      else
        printf '%s: premission denied\n' "$f" >&2
        err=1
      fi
    done

  # no args, read from stdin
  else
    curl -F 'sprunge=<-' http://sprunge.us || err=1
  fi

  return "$err"
}
