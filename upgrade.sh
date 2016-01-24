#!/bin/bash

# Script to assist in resolving dependencies for slackbuild updates
# Depends exclusively on well maintained queue files

# Copyright 2016  Chris Abela, Malta
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

function step1() {
  # Executes Step 1 of the algorithm
  # Usage: step1 upgrade.sqf > step1.out
  # Remove any text after the # character
  # Remove empty lines
  # Sort them alphanumnerically
  # Remove duplicate lines
  # Add a white space and "u" character to unhighlight the packaage
  sed 's/#.*$//g
    /^$/d
    s/^\(.*\)$/\1 u/g' $1 \
    | sort -n \
    | uniq
}

function step2() {
# Executes Step 2 of the algorithm
# Usage: step2 step1.out > step2.out
# Assume that the input file from step 1 is called as the first positional parameter: $1
while read -r LINE; do
  # Read step1.out LINE by LINE
  # Check the second field (h-highlighted or u-unhighlited )
  HU=$( echo $LINE | awk '{print $2}' )
  if [ $HU == u ]; then
    # If unhighlighted
    # Extract the package name (field 1 of LINE)
    PACKNAME=$( echo $LINE | awk '{print $1}' )
    # Highlight the PACKNAME
    echo "$PACKNAME h"
    # Scan for @${PACKNAME} in *.sqf files
    # From this list remove PACKNAME.sqf and upgrade.sqf
    # Check if $PACKNAME may be found in the beginning of a line or
    # at the end of a line
    # or in the middle of a line
    # If positive let us know the file name then
    # Strip the .sqf suffix and
    # Add the u field to unhighlight it
    for i in *sqf; do
      echo $i | egrep -qv "$PACKNAME.sqf|upgrade.sqf" && \
        sed 's/#.*$//' $i | \
        egrep -qe "^@${PACKNAME}$|^@${PACKNAME} | @${PACKNAME}$| @${PACKNAME} |^${PACKNAME}$|^${PACKNAME} | ${PACKNAME}$| ${PACKNAME} " && \
        echo -n $i | \
        sed 's/\.sqf$//g' && \
        echo " u"
    done
  # If highlighted just spit the line out
  else echo $LINE
  fi
done < $1
}

function step3() {
  # Executes Step3 of the Algorithm
  # Usage: step3 step2.out
  # Will return a "1" if the Algorithm is not to be terminated
  # Will return a "2" if the Algorithm is to be terminated
  # If all the packages have been highlighted then we stop
  # If at least one package is unhighlighted, then we continue
  awk '{print $2}' $1 | grep -q u && return 1 || return 2
}

function step4() {
  # Executes Step4 of of the Algorithm
  # Usage: step4 step2.out > step4.out
  # This script will read step2.out line by line
  # If, and only if the contents of the line are not found in the rest of the file
  # the line will be spat to standard output
  # otherwise it would loose its place and would be "unhighlighted"
  I=1 # Line number plus 1
  while read -r LINE; do
    let 'I += 1' # Increment I
    PACKNAME=$( echo $LINE | awk '{print $1}' )
    awk '{print $1 }' $1 | tail +$I | grep -qw $PACKNAME || echo $LINE
  done < $1
}

OUT=${OUT:-/tmp/queue}
N=2
rm -f queue.sqf
ITERATIONS=0
echo -n "No of Iterations = "
step1 upgrade.sqf > $OUT
while true ; do
  let "ITERATIONS += 1" 
  echo -n "${ITERATIONS} "
  step2 $OUT > ${OUT}.2
  step3 ${OUT}.2
  if [ $? -eq 2 ]; then 
    mv ${OUT}.2 $OUT
    # Replace the highlighted field with the sqf suffix of the file
    for i in  $( sed 's/ h/.sqf/' /tmp/queue ); do
    # We need the filename to get its last line
      if [ -e $i ]; then
        tail -1 $i >> queue.sqf
        # The last line might have options that we need
      else # The file does not exist so we just extract the package from the queue file name
        echo $i | sed 's/\.sqf$//' >> queue.sqf
      fi
    done
    echo
    cat queue.sqf
    exit
  fi
  step4 ${OUT}.2 > $OUT
done
