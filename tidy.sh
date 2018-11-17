#!/bin/bash
# 功能:
# 1. 创建ISSUE,状态为TODO
# 2. 打开ISSUE,参数为序号
# 3. 归档ISSUE,按月存放
# 4. 修改ISSUE状态为DONE
# 5. 重新分配序号

# 为了在脚本中支持通过alias自定义的命令(代码中的em命令实际上调用了emacs client工具)
source ~/.bash_profile

# 参数说明
function echoHelp()
{
    echo "Usage: thisscript [-d] 00-99"
    echo "       thisscript ARC | REF"
    echo "# 00-99 序号不存在时创建ISSUE并打开,存在时直接打开"
    echo "# -d 将指定序号的ISSUE设置为DONE状态"
    echo "# -a 归档状态为DONE的ISSUE(月末归档至文件夹)"
    echo "# -r 刷新状态为TODO的ISSUE(月初重新分配序号)"
}

DEBUG=OFF
MONTH_ABB=(nul jan feb mar apr may jun jul aug sep oct nov dec)
WEEK_ABB=(nul non tue wed thu fri sat sun)
DIR_NAME=null

# 调试打印
function echoDebug()
{
    if [ x$DEBUG = xON ];then
	echo "DEBUG: $1"
    fi
}

# 判断是否是数字
function is00_99()
{
    if [ "$1" -gt 0 ] 2>/dev/null ;then
	echoDebug "00-99 yes"
	return 0 
    else
	echoDebug "00-99 no"
	return 1
    fi
}

# 打开文件
# $1 序号
# return 0 序号存在直接打开
# return 1 序号不存在,根据用户输入,新建并打开文件
function open()
{
    MAX=00
    for file in `ls`
    do
	len=${#file}
	if [ $len -gt 9 ]; then # 文件一般长度大于9 "00TODO.md"
	    n=${file:0:2}
	    is00_99 $n
	    if [ $? = 0 ]; then
		if [ $n -gt $MAX ] ; then 
		    MAX=$n
		fi
	    fi
	    if [ $1 = $n ]; then
		echo "OPEN: $file"
		em $file
		return 0
	    fi
	fi
    done
    MAX=`expr $MAX + 1`
    if [ $MAX -lt 10 ];then
	MAX=0$MAX
    fi
    echo "Please input new ISSUE name:"
    read
    if [ $1 = 00 ]; then
	newFile=${MAX}${REPLY}TODO.md
    else
	newFile=$1${REPLY}TODO.md
    fi
    echo "NEW: $newFile"
    em $newFile
    return 1	 
}

# 后缀变为DONE
# $1 ISSUE的序号
# return 0 成功更新状态
# return 1 ISSUE的状态已经是DONE
# return 2 ISSUE的序号不存在
function makeDone()
{
    for file in `ls`
    do
	len=${#file}
	if [ $len -gt 9 ]; then
	    n=${file:0:2}
	    if [ $1 = $n ]; then
		len=${#file}
		newName=${file:0:$len-7}
		stats=${file:$len-7:4}
		if [ x$stats = xDONE ]; then
		    echo "ISSUE: $file"
		    echo "ERROR: ISSUE is already DONE"
		    return 1
		fi
		newFile=${newName}DONE.md
		echo "DONE: $newFile"
		mv $file $newFile
		return 0
	    fi
	fi
    done
    echo "ERROR: Sequence number does not exist"
    return 2
}

# 创建月份文件夹
# 并将文件夹名保存到变量DIR_NAME
function monthDir()
{
    if [ x$MACHTYPE == xx86_64-apple-darwin17 ];then
        MONTH=$(date -j -f "%Y-%m-%d" "${TARGET_DATE}" +%m)
    else
        MONTH=$(date +%m -d "$TARGET_DATE")
    fi
    
    MONTH_SHORT=${MONTH##*0}
    DIR_NAME=_${MONTH}${MONTH_ABB[$MONTH_SHORT]}
    echo $DIR_NAME
    mkdir -p ${DIR_NAME}
    return 0
}

# 归档状态为DONE的ISSUE
function archive()
{
    count=0
    monthDir
    for file in `ls`
    do
	len=${#file}
	if [ $len -gt 9 ]; then
	    newName=${file:0:$len-7}
	    stats=${file:$len-7:4}
	    if [ x$stats = xDONE ]; then
	      echo $file
	      mv $file $DIR_NAME
	    fi
	fi
    done
    return 0;
}

# 重新分配序号
function refresh()
{
    count=01
    for file in `ls`
    do
	len=${#file}
	if [ $len -gt 9 ]; then
	    n=${file:0:2}
	    is00_99 $n
	    if [ $? = 0 ]; then
		newFile=$count${file:2}
		echo "ISSUE: $newFile"
		mv $file $newFile
		count=`expr $count + 1`
		if [ $count -lt 10 ];then
		    count=0$count
		fi
	    fi
	fi
    done
}

# 重新命名
# $1 ISSUE的序号
# return 0 成功更新状态
# return 1 序号不存在
function rename()
{
    for file in `ls`
    do
	len=${#file}
	if [ $len -gt 9 ]; then
	    n=${file:0:2}
	    if [ $1 = $n ]; then
		len=${#file}
		newName=${file:0:$len-7}
		stats=${file:$len-7:4}
		echo "Please input new ISSUE name:"
		read
		newFile=$n${REPLY}${stats}.md
		echo "ISSUE: $newFile"
		mv $file $newFile
		return 0
	    fi
	fi
    done
    echo "ERROR: Sequence number does not exist"
    return 1
}

# 参数处理函数
function run()
{
    is00_99 $1
    if [ $? = 0 ]; then # 打开
	echoDebug "open target"
	open $1
	return 0
    elif [ x$1 = x ]; then # 新建
	echoDebug "new open"
	open 00
	return 0
    elif [ x$1 = x-d ];then # 变更状态为完成
	is00_99 $2
	if [ $? = 0 ]; then
            echoDebug "make done"
	    makeDone $2
	    return 0
	fi
    elif [ x$1 = x-a ];then # 归档
	echoDebug "archive"
	archive
	return 0
    elif [ x$1 = x-r ];then # 重新分配序号
	echoDebug "refresh sequence"
	refresh
	return 0
    elif [ x$1 = x-n ];then # 重命名(序号,状态不变)
	echoDebug "rename"
	is00_99 $2
	if [ $? = 0 ]; then
	    rename $2
	    return 0
	fi
    fi
    
    echoDebug "error"
    echoHelp
}

run $*
