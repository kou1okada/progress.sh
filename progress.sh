#!/usr/bin/env bash

source hhs.bash 0.2.0



# EMBED_BEGIN: verbosefor for Embedding

function verbosefor () # [<level>]
#   Provide a target of redirect for verbose output.
#   This function returns /dev/stderr
#   when $OPT_VERBOSE_LEVEL is greater than or equals to <level>,
#   otherwise /dev/null.
{
  (( ${OPT_VERBOSE_LEVEL:-1} < ${1:-1} )) && echo "/dev/null" || echo "/dev/stderr"
}

verbosefor0="$(verbosefor 0)"
verbosefor1="$(verbosefor 1)"
verbosefor2="$(verbosefor 2)"
verbosefor3="$(verbosefor 3)"
verbosefor4="$(verbosefor 4)"
verbosefor5="$(verbosefor 5)"

# EMBED_END: verbosefor for Embedding



# EMBED_BEGIN: progress.sh for Embedding
# EMBED_REQUIRE: verbosefor
# Progress.sh
# Copyright (c) 2018 Koichi OKADA. All rights reserved.
# This script is distributed under the MIT license.

readonly PROGRESS_CHAR=( '=' '-' '/' '|' '\' )

function progress_percent_prepare ()
#   Prepare percentage indicator for progress bar.
{
  [[ -n "$OPT_NO_PROGRESS_PERCENT" ]] && return
  if [[ -n "$PROGRESS_PERCENT_PID" ]]; then
    error "Already set PROGRESS_PERCENT_PID: $PROGRESS_PERCENT_PID"
    return 1
  fi
  
  local fifo n=0 total="$PROGRESS_TOTAL"
  
  mkfifo /tmp/progress.$$
  
  while true; do
    fifo="$(</tmp/progress.$$)"
    let n++
    printf "\e[55G%3d%%" $(( 100 * n / total )) >"$verbosefor0"
    (( total <= n )) && exit
  done &
  PROGRESS_PERCENT_PID=$!
}

function progress_percent_update ()
#   Cleanup percentage indicator for progress bar.
{
  [[ -n "$OPT_NO_PROGRESS_PERCENT" ]] && return
  echo -n > /tmp/progress.$$
}

function progress_percent_cleanup ()
#   Update percentage indicator for progress bar.
{
  if [[ -n "$PROGRESS_PERCENT_PID" ]]; then
    wait "$PROGRESS_PERCENT_PID"
    unset PROGRESS_PERCENT_PID
  fi
  rm -r /tmp/progress.$$
}

function progress_init () # [<total=100>]
#   Initialize progress bar.
{
  [ -n "$OPT_NO_PROGRESS" ] && return
  if [[ -n "$PROGRESS_TOTAL" ]]; then
    error "Already initialized other progress bar."
    return 1
  fi
  PROGRESS_TOTAL="${1:-100}"

  [ -n "$OPT_NO_PROGRESS_SCALE" ] || \
  echo     "|+----+----+----+----+----|----+----+----+----+----+|"   >"$verbosefor0"
  echo -ne "|...................................................|\r" >"$verbosefor0"
  #          0         1         2         3         4         5
  #          012345678901234567890123456789012345678901234567890
  
  progress_percent_prepare
}

function progress_update () # <current>
#   Update progress bar.
{
  [ -n "$OPT_NO_PROGRESS" ] && return
  local n="$PROGRESS_TOTAL"
  local p=$((2 + 50 * ($1    ) / n))
  local q=$((2 + 50 * ($1 + 1) / n))
  
  progress_percent_update
  
  if (( q - p <= 1 )); then
    printf "\e[%dG%s" $p "${PROGRESS_CHAR[($1 % 4 + 1) * (1 + $p - $q)]}"
  elif (( $1 == n )); then
    printf "\e[%dG%s" $p "="
  else
    local finished="$(printf "%*s" $((q - p)) "")"; finished="${finished//?/=}"
    printf "\e[%dG%s" $p "$finished"
  fi >"$verbosefor0"
}

function progress_finish ()
#   Finish progress bar.
{
  [ -n "$OPT_NO_PROGRESS" ] && return
  
  progress_percent_cleanup
  
  echo -e "\r|===================================================|" >"$verbosefor0"
  #           0         1         2         3         4         5
  #           012345678901234567890123456789012345678901234567890
  unset PROGRESS_TOTAL
}

# EMBED_END: progress.sh



function progress_demo () # [<total=100> [<wait=0>]]
#   Demonstration for Progress bar.
{
  local i total="${1:-100}" wait="${2:-0}"
  progress_init $total
  for (( i = 0; i < total; i++ )); do
    [[ "$wait" != "0" ]] && sleep $wait
    progress_update $i
  done;
  progress_finish
}



has_subcommand_progress=1

function optparse_progress ()
{
  case "$1" in
  --no-progress)
    #   Hide progress.
    nparams 0
    optset NO_PROGRESS "$1"
    ;;
  --no-progress-scale)
    #   Hide scale for progress.
    nparams 0
    optset NO_PROGRESS_SCALE "$1"
    ;;
  --no-progress-percent)
    #   Hide scale for progress.
    nparams 0
    optset NO_PROGRESS_PERCENT "$1"
    ;;
  *) return 1 ;;
  esac
}

function progress () # [<command> [<parameters> ...]] 
#   Progress bar for bash script.
{
  invoke_help
}

invoke_command "$@"
