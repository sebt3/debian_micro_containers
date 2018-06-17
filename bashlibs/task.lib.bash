#!/bin/bash
# BSD 3-Clause License
# 
# Copyright (c) 2017-2018, Sébastien Huss
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


net.resolve() {
	if is.function net.resolver;then
		net.resolver "$@"
		return $?
	fi
	echo "$@"
}
net.run() { ssh -q -o PasswordAuthentication=no "$@"; }
net.runFunction() { net.run "$1" "$(typeset -f $2|awk 'NR>3 {print last} {last=$0}')"; }

TASK_target=()
TASK_name=()
TASK_verify=()
TASK_desc=()
TASK_defaultVerify=${TASK_defaultValidate:-"task.verify"}
TASK_translateTarget=${TASK_translateTarget:-"echo"}
TASK_awkFilter=${TASK_awkFilter:-'/No such file or directory/{L=E}'}
TASK_useHost=0
task.add() {
	local target=""
	local i=${#TASK_name[@]}
	if ! is.function $1;then
		target=$1;shift
		TASK_useHost=1
	fi
	if ! is.function $1;then
		out.error "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}: $1 is not a function cannot add that task to the list"
		return 1
	fi
	TASK_name+=($1)
	shift
	TASK_desc[$i]="$*"
	TASK_target[$i]="$target"
	if is.function ${TASK_name[$i]}.verify;then
		TASK_verify[$i]="${TASK_name[$i]}.verify"
	else
		TASK_verify[$i]="$TASK_defaultVerify"
	fi
}
task.handleOut() {
	gawk -vD=$1 'BEGIN{E="ERROR";W="WARNING"}{print;L=D}'"$TASK_awkFilter"'{print L" "$0 >"/dev/fd/6";fflush("/dev/fd/6") }'
}
task.handleOutRem() {
	gawk -vD=$1 -vR=$2 'BEGIN{E="ERROR";W="WARNING"}{print;L=D}'"$TASK_awkFilter"'{print L" "R": "$0 >"/dev/fd/6";fflush("/dev/fd/6") }'
}

task.verify.rc() {
	if ! [ ${TASK_ret:-0} -eq ${1:-0} ];then
		out.notice "${TASK_name[$TASK_current]} returned $TASK_ret"
		return 1
	fi
	return 0
}
task.verify.stdout() {
	local L
	for L in $(gawk -vD=STDOUT 'BEGIN{E="ERROR";W="WARNING"}{L=D}'"$TASK_awkFilter"'{print L}' <<<"${TASK_out:-""}"|sort -u);do
		if [[ $L == "ERROR" ]];then
			out.notice "${TASK_name[$TASK_current]} have generated errors on stdout"
			return 1
		fi
	done 
	return 0
}
task.verify.stderr() {
	local L
	for L in $(gawk -vD=STDERR 'BEGIN{E="ERROR";W="WARNING"}{L=D}'"$TASK_awkFilter"'{print L}' <<<"${TASK_err:-""}"|sort -u);do
		if [[ $L == "ERROR" ]];then
			out.notice "${TASK_name[$TASK_current]} have generated errors on stderr"
			return 1
		fi
	done
	return 0
}
task.verify.stderr.empty() {
	if ! [ -z "$TASK_err" ];then
		out.notice "${TASK_name[$TASK_current]} have generated errors on stderr"
		return 1
	fi
	return 0
}
task.verify() {
	local r=0
	task.verify.stdout || r=3
	task.verify.stderr.empty || r=2
	task.verify.rc || r=1
	return $r
}
task.verify.permissive() {
	local r=0
	task.verify.stdout || r=3
	task.verify.stderr || r=2
	task.verify.rc || r=1
	return $r
}
task.list() {
	local i
	if [ $TASK_useHost -eq 0 ];then
		printf "[##]_Task____________________________Description____________________________________\n"
		for ((i=0;i<${#TASK_name[@]};i++));do
			printf "[%2d] %-31s %s\n" "$i" "${TASK_name[$i]}" "${TASK_desc[$i]}"
		done
	else
		printf "[##]_Host__________________Task____________________________Description____________________________________\n"
		for ((i=0;i<${#TASK_name[@]};i++));do
			printf "[%2d] %-21s %-31s %s\n" "$i" "${TASK_target[$i]}" "${TASK_name[$i]}" "${TASK_desc[$i]}"
		done
	fi
}
task.ctrl() {
	# close all non-usefull filedescriptor
	(
		local n
		for n in $(find /proc/$BASHPID/fd -type l -printf '%f\n');do
			((n > 4)) && eval "exec $n>&-"
		done
		eval "$@"
	)
}
task.runUnit() {
	local id=$1;shift
	local name=$1;shift
	local desc="$@"
	out.task "[$id] ${desc}"
	if is.function "${name}.precheck";then
		eval "${name}.precheck";ret=$?;
		if [ $ret -ne 0 ];then
			out.error "precheck for \"${desc}\" have failed"
			out.lvl FAIL "[$id] ${desc}"
			return $ret
		fi
	fi
	oldfd=${OUT_fd:-1};
	if [ $oldfd -eq 1 ];then
		exec 4>&1;OUT_fd=4
	elif [ $oldfd -eq 4 ];then
		exec 5>&1;LOG_fd=5
	fi
	eval "$( task.ctrl $name  2> >(err=$(task.handleOut STDERR); typeset -p err) > >(out=$(task.handleOut STDOUT); typeset -p out); ret=$?; typeset -p ret )"
	if [ $oldfd -eq 1 ];then
		exec >&- >&4;OUT_fd=${oldfd}
	elif [ $oldfd -eq 4 ];then
		exec >&- >&5;LOG_fd=1
	fi
	TASK_out=$out TASK_err=$err TASK_ret=$ret ${TASK_verify[$i]};ret=$?
	if [ $ret -ne 0 ];then
		out.lvl FAIL "[$id] ${desc}"
		return $ret
	else
		out.ok "[$id] ${desc}"
	fi
}
task.runTarget() {
	local id=$1;shift
	local target=$1;shift
	local name=$1;shift
	local desc="$@"
	out.task "[$id][$target] ${desc}"
	if is.function "${name}.precheck";then
		net.runFunction "$target" "${name}.precheck";ret=$?;
		if [ $ret -ne 0 ];then
			out.error "precheck for \"${desc}\" have failed"
			out.lvl FAIL "[$id][$target] ${desc}"
			return $ret
		fi
	fi
	oldfd=${OUT_fd:-1};
	if [ $oldfd -eq 1 ];then
		exec 4>&1;OUT_fd=4
	elif [ $oldfd -eq 4 ];then
		exec 5>&1;LOG_fd=5
	fi
	eval "$( net.runFunction "$target" "$name"  2> >(err=$(task.handleOutRem STDERR $target); typeset -p err) > >(out=$(task.handleOutRem STDOUT $target); typeset -p out); ret=$?; typeset -p ret )"
	if [ $oldfd -eq 1 ];then
		exec >&- >&4;OUT_fd=${oldfd}
	elif [ $oldfd -eq 4 ];then
		exec >&- >&5;LOG_fd=1
	fi
	TASK_out=$out TASK_err=$err TASK_ret=$ret ${TASK_verify[$i]};ret=$?
	if [ $ret -ne 0 ];then
		out.lvl FAIL "[$id][$target] ${desc}"
		return $ret
	else
		out.ok "[$id][$target] ${desc}"
	fi
}
task.run() {
	local min=${1:-0}
	local max=${2:-$(( ${#TASK_name[@]} - 1 ))}
	local i out err ret oldfd logdf lvl line h
	exec 6> >(while read lvl line;do out.lvl $lvl "$line";done)
	for ((i=$min;i<=$max;i++));do
		TASK_current=$i
		if [[ "${TASK_target[$i]}" == "" ]];then
			task.runUnit "$i" "${TASK_name[$i]}" "${TASK_desc[$i]}" || return $?
		else
			for h in $(net.resolve "${TASK_target[$i]}");do
				task.runTarget  "$i" "$h" "${TASK_name[$i]}" "${TASK_desc[$i]}"  || return $?
			done
		fi
	done
	exec 6>&-
	return 0
}
task.script() {
	local i
	MIN=0
	MAX=$(( ${#TASK_name[@]} - 1 ))
	args.declare MIN  -b --begin Vals NoOption NotMandatory "Begin at that task"
	args.declare MAX  -e --end   Vals NoOption NotMandatory "End at that task"
	args.declare ONLY -o --only  Vals NoOption NotMandatory "Only run this step"
	ARGS_helpCallback=task.list
	args.use.help
	args.parse "$@"
	if ! is.number $MIN || ! is.number $MAX;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $MIN && [[ "$MIN" == "${TASK_name[$i]}" ]];then
				MIN=$i
			fi
			if ! is.number $MAX && [[ "$MAX" == "${TASK_name[$i]}" ]];then
				MAX=$i
			fi
		done
	fi
	if ! is.number $MIN || [ $MIN -lt 0 ] || [ $MIN -ge ${#TASK_name[@]} ];then
		out.error "\"$MIN\" is an invalid value for MIN"
		return 1
	fi
	if ! is.number $MAX || [ $MAX -lt 0 ] || [ $MAX -ge ${#TASK_name[@]} ];then
		out.error "\"$MAX\" is an invalid value for MAX"
		return 1
	fi
	if [ ! -z "$ONLY" ] && ! is.number $ONLY;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $ONLY && [[ "$ONLY" == "${TASK_name[$i]}" ]];then
				ONLY=$i
			fi
		done
		if ! is.number $ONLY;then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
	fi
	if [ ! -z "$ONLY" ];then
		if ! is.number $ONLY || [ $ONLY -lt 0 ] || [ $ONLY -ge ${#TASK_name[@]} ];then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
		MIN=$ONLY
		MAX=$ONLY
	fi
	mkdir -p $LOG_dir
	log.start
	task.run "$MIN" "$MAX"
	log.end
}

ACTIVITY_name=()
ACTIVITY_desc=()
act.add() {
	if ! is.function $1;then
		out.warn "\"$1\" is not a function, cannot add as activity"
		return 1
	fi
	local i=${#ACTIVITY_name[@]}
	ACTIVITY_name+=($1)
	shift
	ACTIVITY_desc[$i]="$*"
}
act.add.post() {
	act.add "$@"
	args.option ACT "$@"
}
act.set() {
	if is.function $1;then
		eval "$1"
	elif is.number $1;then
		eval "${ACTIVITY_name[$1]}"
	else
		out.error "Cannot set \"$1\" activity"
		return 1
	fi
}
act.script() {
	local i
	MIN=0
	#MAX=
	args.option.declare ACT -a --activity Mandatory C "Select the activity to run"
	for (( i=0; i<${#ACTIVITY_name[@]}; i++ ));do
		args.option ACT "${ACTIVITY_name[$i]}" "${ACTIVITY_desc[$i]}"
	done
	ARGS_short_cmd=(ACT "${ARGS_short_cmd[@]}")
	args.declare LST  -l --list  NoVal NoOption NotMandatory "List all available tasks"
	args.declare MIN  -b --begin Vals  NoOption NotMandatory "Begin at that task"
	args.declare MAX  -e --end   Vals  NoOption NotMandatory "End at that task"
	args.declare ONLY -o --only  Vals  NoOption NotMandatory "Only run this step"
	args.use.help
	args.parse "$@"
	act.set $ACT
	if [ ${#TASK_name[@]} -eq 0 ];then
		out.error "No task to run"
		return 1
	fi
	if ! is.set MAX;then
		MAX=$(( ${#TASK_name[@]} - 1 ))
	fi
	if ! is.number $MIN || ! is.number $MAX;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $MIN && [[ "$MIN" == "${TASK_name[$i]}" ]];then
				MIN=$i
			fi
			if ! is.number $MAX && [[ "$MAX" == "${TASK_name[$i]}" ]];then
				MAX=$i
			fi
		done
	fi
	if ! is.number $MIN || [ $MIN -lt 0 ] || [ $MIN -ge ${#TASK_name[@]} ];then
		out.error "\"$MIN\" is an invalid value for MIN"
		return 1
	fi
	if ! is.number $MAX || [ $MAX -lt 0 ] || [ $MAX -ge ${#TASK_name[@]} ];then
		out.error "\"$MAX\" is an invalid value for MAX"
		return 1
	fi
	if [ ! -z "$ONLY" ] && ! is.number $ONLY;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $ONLY && [[ "$ONLY" == "${TASK_name[$i]}" ]];then
				ONLY=$i
			fi
		done
		if ! is.number $ONLY;then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
	fi
	if [ ! -z "$ONLY" ];then
		if ! is.number $ONLY || [ $ONLY -lt 0 ] || [ $ONLY -ge ${#TASK_name[@]} ];then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
		MIN=$ONLY
		MAX=$ONLY
	fi
	if [[ "$LST" == "Y" ]];then
		echo "Activity \"$ACT\":"
		task.list
		echo
	else
		mkdir -p $LOG_dir
		[ $(out.levelID $LOG_level) -ne 0 ] && log.start
		task.run "$MIN" "$MAX"
		[ $(out.levelID $LOG_level) -ne 0 ] && log.end
	fi
}
