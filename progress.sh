#!/usr/bin/env bash

source hhs.bash 0.2.0



# Lesser Parallel for Embedding
# Copyright (c) 2014 Koichi OKADA. All rights reserved.
# The official repository is:
# https://github.com/kou1okada/lesser-parallel
# This script is distributed under the MIT license.
# http://www.opensource.org/licenses/mit-license.php

LESSER_PARALLEL_MAX_JOBS=${LESSER_PARALLEL_MAX_JOBS:-8}

function lesser-parallel-get-jobs-count ()
#   Get number of current runnning jobs.
{
  jobs -l >/dev/null
  jobs -l | wc -l
}

function lesser-parallel-restrict-jobs-count () # <maxjobs>
#   Wait the number of running jobs will be reduced
#   if the number of current runnning jobs is over <maxjobs>.
{
  while (( $1 <= $(lesser-parallel-get-jobs-count) )); do
    sleep 0.2
  done
}

function lesser-parallel () # [<command> [<arguments> ...]] < <list_to_arguments>
#   Execute <command> by parallel.
# Arguments:
#   Each jobs receive input line from STDIN into placeholders.
#   Placeholders will be substituted with input line as below:
#   {}   : Input line.
#   {.}  : Input line without extention (pathname).
#   {/}  : Input line without directory (basename).
#   {//} : Input line without basename (dirname).
#   {/.} : Input line without directory and extension (basename without suffix).
#   {#}  : Job sequence number of paralell.
{
  local cmd arg line basename ext PARALLEL_SEQ=1
  while read line; do
    basename="$(basename "$line")"
    ext="${basename##*.}"
    [[ "$ext" == "$basename" ]] && ext=""
    [[ "$ext" != "" ]] && ext=".$ext"
    cmd=( )
    for arg; do
      case "$arg" in
      "{}")   cmd+=( "$line" ) ;;
      "{.}")  [[ -z "$ext" ]] && cmd+=( "$line" ) || cmd+=( "${line%.*}" ) ;;
      "{/}")  cmd+=( "$basename" ) ;;
      "{//}") cmd+=( "$(dirname "$line")" ) ;;
      "{/.}") cmd+=( "$(basename "$basename" "$ext")" ) ;;
      "{#}")  cmd+=( "$PARALLEL_SEQ" ) ;;
      *)      cmd+=( "$arg" ) ;;
      esac
    done
    
    lesser-parallel-restrict-jobs-count $LESSER_PARALLEL_MAX_JOBS
    
    "${cmd[@]}" &
    let PARALLEL_SEQ++
  done
  
  lesser-parallel-restrict-jobs-count 1
}

#/Lesser Parallel for Embedding



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
  
  local n=0 total="$PROGRESS_TOTAL"
  
  exec 3<>/tmp/progress.$$
  
  {
    while true; do
      n="$(stat -c %s /tmp/progress.$$)"
      (( total < n )) && let n=total
      printf "\e[55G%3d%%" $(( 100 * n / total )) >"$verbosefor0"
      (( total <= n )) && exit
    done
    exec 3>&-
    exec 3<&-
  } &
  PROGRESS_PERCENT_PID=$!
}

function progress_percent_update ()
#   Cleanup percentage indicator for progress bar.
{
  [[ -n "$OPT_NO_PROGRESS_PERCENT" ]] && return
  echo -n . >&3
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
  local total="$PROGRESS_TOTAL"
  local current=$(($1 < total ? $1 : total))
  local p=$((2 + 50 * (current    ) / total))
  local q=$((2 + 50 * (current + 1) / total))
  
  progress_percent_update
  
  if (( q - p <= 1 )); then
    printf "\e[%dG%s" $p "${PROGRESS_CHAR[($1 % 4 + 1) * (1 + $p - $q)]}"
  elif (( current == n )); then
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

function progress_demo_lp_job () # <current> <wait>
{
  local i current=$1 wait=$2
  for (( i = 0; i < 10; i++ )); do
    [[ "$wait" != "0" ]] && sleep $wait
    progress_update $current
    let current++
  done
}

function progress_demo_lp () # [<total=100> [<wait=0>]]
#   Demonstration for Progress bar with lesser-parallel.
{
  local i total="${1:-100}" wait="${2:-0}"
  progress_init $total
  seq 0 10 $total | lesser-parallel progress_demo_lp_job {} $wait
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
