#!bash
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
    echo "# ARC 归档状态为DONE的ISSUE(月末归档至文件夹)"
    echo "# REF 刷新状态为TODO的ISSUE(月初重新分配序号)"
}

DEBUG=ON
FUNC=(OPEN DONE ARC REF ERR)
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
		em $file
		return 0
	    fi
	fi
    done
    MAX=`expr $MAX + 1`
    if [ $MAX -lt 10 ];then
	MAX=0$MAX
    fi
    echo "请输入ISSUE名称:"
    read
    if [ $1 = 00 ]; then
        echoDebug ${MAX}${REPLY}TODO.md
	em ${MAX}${REPLY}TODO.md
    else
	echoDebug $1${REPLY}TODO.md
	em $1${REPLY}TODO.md
    fi
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
		    echo "ERROR: ISSUE的状态已经是DONE"
		    return 1
		fi
		mv $file ${newName}DONE.md
		return 0
	    fi
	fi
    done
    echo "ERROR: ISSUE的序号不存在"
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
    DIR_NAME=${MONTH}${MONTH_ABB[$MONTH_SHORT]}
    echoDebug $DIR_NAME
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
		mv $file $count${file:2}
		count=`expr $count + 1`
		if [ $count -lt 10 ];then
		    count=0$count
		fi
	    fi
	fi
    done
}

# 参数处理函数
function run()
{
    is00_99 $1
    if [ $? = 0 ]; then
	echoDebug "open specified"
	open $1
        return 1
    elif [ x$1 = x ]; then
	echoDebug "open default"
	open 00
	return 1
    elif [ x$1 = x-d ];then
	is00_99 $2
	if [ $? = 0 ]; then
            echoDebug "make done"
	    makeDone $2
           return 2
	fi
    elif [ x$1 = xARC ];then
	echoDebug "archive"
	archive
	return 3
    elif [ x$1 = xREF ];then
	echoDebug "refresh"
	refresh
	return 4
    fi
    
    echoHelp
    echoDebug "error"
    return 5
}

run $*
