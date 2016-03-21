#!/bin/bash

# Script to assist in resolving dependencies for slackbuild updates
# Depends exclusively on well maintained queue files

# Copyright 2016  Chris Abela <kristofru@gmail.com>, Malta
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
  # Remove any text after the # character
  # Remove empty lines
  # Sort them alphanumnerically
  # Remove duplicate lines
  # Add a white space and "u" character to unhighlight the package
  STEP1OUT=$(  sed 's/#.*$//g
    /^$/d' $1 \
    | sort -n \
    | uniq )
  for i in $STEP1OUT; do
    STEP1UH="$STEP1UH u"
  done
}

function step2() {
  # Executes Steps 2 and 5 of the algorithm
  unset STEP2OUT STEP2UH
  COUNTER=0
  for HU in $2; do
    # Read step1out field at a time
    # Check step1uh (h-highlighted or u-unhighlited )
    let 'COUNTER += 1'; # Increment the Counter 
    # Extract the package name (field 1 of LINE)
    PACKNAME=$( echo $1 | awk "{ print \$$COUNTER}" )
    STEP2OUT=$( echo "$STEP2OUT $PACKNAME" )
    # Highlight the package
    STEP2UH=$( echo "$STEP2UH" "h" )
    if [ $HU == u ]; then
      # If unhighlighted
      # Highlight the PACKNAME
      # Scan for ${PACKNAME} in *.sqf files
      # From this list remove PACKNAME.sqf and upgrade.sqf
      # If successful remove comment textning with a "#"
      # Check if $PACKNAME may be found in the beginning of a line or
      # at the end of a line
      # or in the middle of a line
      # If positive let us know the file name then
      # Strip the .sqf suffix and
      # Add the result to STEP2OUT
      # If positive add a 'u' to STEP2UH  
      for i in *sqf; do
        NEWPACKS=$( echo $NEWPACKS $( echo $i | egrep -qv "$PACKNAME.sqf|upgrade.sqf" && \
          sed 's/#.*$//' $i | \
          egrep -qe "^@${PACKNAME}$|^@${PACKNAME} | @${PACKNAME}$| @${PACKNAME} |^${PACKNAME}$|^${PACKNAME} | ${PACKNAME}$| ${PACKNAME} " && \
            echo "$i" | \
            sed 's/\.sqf$//g' ))
      done
    STEP2OUT=$( echo "$STEP2OUT $NEWPACKS" )
    # New Packages will be unhlighlited
    for i in $NEWPACKS; do
      STEP2UH=$( echo "$STEP2UH u" )
    done
    # Reset NEWPACKS
    unset NEWPACKS
    fi
  done
}

function step3() {
  # Executes Step3 of the Algorithm
  # Will return a "1" if the Algorithm is not to be terminated
  # Will return a "2" if the Algorithm is to be terminated
  # If all the packages have been highlighted then we stop
  # If at least one package is unhighlighted, then we continue
  echo "$1" | grep -q 'u' && return 1 || return 2
}

function step4() {
  # Executes Step4 of of the Algorithm
  # This script will read STEP2OUT line by line
  # If, and only if the contents of the line are not found in the rest of the file
  # the line will be augemented to STEP4OUT
  # otherwise it would loose its place
  unset STEP4OUT STEP4UH
  COUNTER1=0
  for i in $1; do
    let 'COUNTER1+=1'
    PACKNAME=$i 
    COUNTER2=0
    Q=0
    UH=$( echo $2 | awk "{ print \$$COUNTER1}" )
    for j in $1; do
      let 'COUNTER2+=1'
      if [ $COUNTER2 -gt $COUNTER1 ]; then
        # P is the remaining packages in STEP2OUT list
        P=$( echo $1 | awk "{ print \$$COUNTER2}" )
        if [ $i = $P ] ;then
          Q=1 # A match has been found
        fi
      fi
    done
    if [ $Q -eq 0 ];then
      # Only if no matches have been found we inherit PACKNAME ...
      STEP4OUT="$STEP4OUT $PACKNAME"
      # ... and UH
      STEP4UH="$STEP4UH $UH"
    fi
  done
}

function hash() {
  # Check if the package is installed
  # If it is not installed prefix the package name
  # with a hash (#)
  VLP=$( basename $( ls /var/log/packages/${PKG}* 2>/dev/null |\
    grep "${PKG}-[^-]*-[^-]*-[^-]*$" | \
    sed 's/-[^-]*-[^-]*-[^-]*$//' ) 2>/dev/null )
    if [ "$VLP" != "$PKG" ]; then
    # PKG is not installed so we print a # in front of the package name 
    echo -n "#" >> $OUT
  fi
}

# By default upgrade.sqf will be the queue file containing the files to upgrade
# but if we have an argument we will try it first
if [ -e "$1" ] ;then 
  # We have an argument and it is a file
  UPGRADE=$1
fi
UPGRADE=${UPGRADE:-upgrade.sqf}
OUT=${OUT:-queue.sqf}
echo "#${OUT}" > $OUT
ITERATIONS=0
echo -e "\tExecuting Step 1"
step1 $UPGRADE
while true; do
  let "ITERATIONS += 1"
  echo "Iteration No. ${ITERATIONS}"
  echo -e "\tExecuting Step 2"
  step2 "$STEP1OUT" "$STEP1UH"
  echo -e "\tExecuting Step 3"
  step3 "$STEP2UH"
  if [ $? -eq 2 ]; then
    for i in $STEP2OUT; do
      j=${i}.sqf # j should be the queue filename (only if it exists)
      if [ -e $j ]; then # We have its queue file
        # Remove blank lines, take the last line and its first field only
        LL=$( sed '/^$/d' $j | tail -1 )
        # The last line might have options that we need to strip away to get to the package name
        PKG=$( echo $LL | awk '{ print $1 }' )
        hash
        echo $LL >> $OUT
      else PKG=$i
        hash
        echo $i >> $OUT # No Queue file was found 
      fi
    done
    echo
    echo "Done, this is the Result:"
    echo
    cat $OUT
    exit
  fi
  echo -e "\tExecuting Step 4" 
  step4 "$STEP2OUT" "$STEP2UH"
  STEP1OUT=$STEP4OUT
  STEP1UH=$STEP4UH
done
