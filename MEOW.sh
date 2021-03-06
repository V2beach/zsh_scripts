#!/bin/bash
#########################################################
# Function :Control proxy and meow                      #
# Platform :All Linux Based Platform                    #
# Version  :1.0                                         #
# Date     :2021-04-15                                  #
# Author   :V2beach                                     #
# Contact  :v2beach1@gmail.com                          #
# Company  :Zhejiang University                         #
#########################################################

#################################################################################################
# 2021-04-15更新：                                                                               #
# 本脚本只能开机时使用，若http代理本来就是打开的，则auto代理无法配置成功                                  #
# 上述现象成因是V2rayU会在另一个线程晚于networksetup命令启动，届时会因开启其他代理而将auto-config关闭       #
# 另外，2>&1用于让nohup的日志重定向写入到非nohup.out的制定文件                                         #
# 2021-04-17更新：                                                                               #
# 1.现在任何时候都能使用了，把MEOW和V2rayU的启动套了一层判断；                                          #
# 2.增加全部关闭的功能，需要传参。                                                                   #
# 2021-04-18更新：                                                                               #
# 由于cow/meow是http的代理，这层代理负责收发http协议数据并学习pac，然后智能分流到v2rayu层的http和socks代理，#
# 这就产生了一个问题，如果有次翻墙（如播客）用的不是http协议而是socks协议，就无法通过cow/meow达到翻墙效果，    #
# 所以需要添加单独删除cow/meow这层代理的功能，以使得系统级代理支持socks协议。（另一种方案是proxifier）       #
# 2021-04-21更新：                                                                               #
# 让CLI也可以通过脚本走代理，但是注意，就算代理了也ping不通，因为不是一个层的协议，具体的协议我忘光了。         #
# 2021-04-27更新：                                                                               #
# exit会导致退出shell，导致作用于当前shell的cliproxy失效，                                            #
# 运行方式——source ~/MEOW.sh -cli。                                                               #
# 2021-05-07更新：                                                                               #
# 放弃用V2rayU作为主力，由于qv2ray也仍无M1版本，只好转回ShadowsocksX-NG(New Generation)，              #
# 但坚守用原生browser的底线——Safari，                                                              #
# 所以稍微改变本代码逻辑，功能跟原先基本一致，但可以选择v2ray或shadowsocks，并增加代码补全，                #
# 与原先不同的是选择v2ray后会检查并关闭shadowsocks，选择shadowsocks之后会检查并关闭v2ray。               #
# 由于直接使用v2ray-core，没有V2rayU启动的延迟，setautoproxyurl也不再需要等待其他代理打开后再接管全局了。   #
# 2021-05-16 Update:
# Modify the code logic, v2ray service needs server serial now, fucow and cli come outside.
#################################################################################################

kill_processes(){
    pids=$(ps -ef | grep "$1" | grep -v grep | grep -v MEOW.sh | awk '{print $2}')
    for pid in $pids
    do
        kill -9 $pid
    done
}

if [[ "$1" == "-v2ray" ]]
then
    if [[ "$2" == "startup" ]]
    then
        # set server serial
        if [[ "$3" == "3" ]] || [[ "$3" == "4" ]] || [[ "$3" == "5" ]]
        then
            file=~/v2ray-macos-arm64-v8a/config.json
            sed -i -e '49s/c7s.*.jamjams.net/c7s'$3'.jamjams.net/' $file
        else
            echo "invalid v2ray server serial: "$3""
            exit
        fi
        
        # stop the other
        kill_processes Shadowsocks
    
        # start meow
        # grep -v grep是去除当前grep MEOW的进程本身，$?是上条命令的返回值，如果是0说明没有搜到
        ps -ef | grep MEOW | grep -v grep | grep -v MEOW.sh
        if [ $? -ne 0 ]
        then
            nohup /Users/v2beach/go/bin/MEOW > /Users/v2beach/LOG/MEOW.log 2>&1 &
        fi
        
        # start V2ray
        ps -ef | grep v2ray | grep -v grep | grep -v MEOW.sh
        if [ $? -ne 0 ]
        then
            nohup /Users/v2beach/v2ray-macos-arm64-v8a/v2ray > /Users/v2beach/LOG/V2ray.log 2>&1 &
            networksetup -setwebproxy Wi-Fi 127.0.0.1 8001
            networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 8001
            networksetup -setsocksfirewallproxy Wi-Fi 127.0.0.1 1081
        fi

        # set gui proxy
        # while true
        # do
            # proxy=`networksetup -getwebproxy Wi-Fi | grep ^Enabled`
            # if [[ $proxy == "Enabled: Yes" ]]
            # then
        networksetup -setautoproxyurl Wi-Fi http://127.0.0.1:7777/pac
                # break
            # fi
        # done

        echo "startup done"
    elif [[ "$2" == "shutdown" ]]
    then
        # launchctl remove yanue.v2rayu.v2ray-core
        kill_processes MEOW
        kill_processes v2ray
        networksetup -setautoproxystate Wi-Fi off
        networksetup -setwebproxystate Wi-Fi off
        networksetup -setsecurewebproxystate Wi-Fi off
        networksetup -setsocksfirewallproxystate Wi-Fi off

        echo "shutdown done"
    else
        echo "unknown option: "$2""
        echo "    usage: ~/MEOW.sh [-v2ray <command>] [-shadowsocks <command>] [-help] [-cow] [-cli]"
    fi

elif [[ "$1" == "-shadowsocks" ]]
then
    if [[ "$2" == "startup" ]]
    then
        # stop the other
        kill_processes v2ray
    
        # start meow
        # grep -v grep是去除当前grep MEOW的进程本身，$?是上条命令的返回值，如果是0说明没有搜到
        ps -ef | grep MEOW | grep -v grep | grep -v MEOW.sh
        if [ $? -ne 0 ]
        then
            nohup /Users/v2beach/go/bin/MEOW > /Users/v2beach/LOG/MEOW.log 2>&1 &
        fi
        
        # start V2ray
        ps -ef | grep Shadowsocks | grep -v grep | grep -v MEOW.sh
        if [ $? -ne 0 ]
        then
            nohup /Applications/ShadowsocksX-NG.app/Contents/MacOS/ShadowsocksX-NG > /Users/v2beach/LOG/ShadowsocksX.log 2>&1 &
            networksetup -setwebproxy Wi-Fi 127.0.0.1 8001
            networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 8001
            networksetup -setsocksfirewallproxy Wi-Fi 127.0.0.1 1081
        fi

        # set gui proxy
        # while true
        # do
            # proxy=`networksetup -getwebproxy Wi-Fi | grep ^Enabled`
            # if [[ $proxy == "Enabled: Yes" ]]
            # then
        networksetup -setautoproxyurl Wi-Fi http://127.0.0.1:7777/pac
                # break
            # fi
        # done

        echo "startup done"
    elif [[ "$2" == "shutdown" ]]
    then
        # launchctl remove yanue.v2rayu.v2ray-core
        kill_processes MEOW
        kill_processes Shadowsocks
        networksetup -setautoproxystate Wi-Fi off
        networksetup -setwebproxystate Wi-Fi off
        networksetup -setsecurewebproxystate Wi-Fi off
        networksetup -setsocksfirewallproxystate Wi-Fi off

        echo "shutdown done"
    else
        echo "unknown option: "$2""
        echo "    usage: ~/MEOW.sh [-v2ray <command>] [-shadowsocks <command>] [-help] [-cow] [-cli]"
    fi

elif [[ "$1" == "-help" ]]
then
    echo "usage: ~/MEOW.sh [-shadowsocks <command>] [-v2ray <command>] [-help]"
    echo "commands after -shadowsocks:"
    echo "    startup     start MEOW, proxy  on, start shadowsocks, kill v2ray"
    echo "    shutdown    stop  MEOW, proxy off, stop  shadowsocks"
    echo "commands after -v2ray:"
    echo "    startup <server serial>"
    echo "                start MEOW, proxy  on, start v2ray according to server serial, kill shadowsocks"
    echo "    shutdown    stop  MEOW, proxy off, stop  v2ray"
    echo "-help, -fucow, -cli:"
    echo "    -help       do nothing except call for help on MEOW.sh"
    echo "    -cow        stop  MEOW, proxy automatic configuration off"
    echo "    -cli        set cli proxy to protocol://localhost:port"

elif [[ "$1" == "-cow" ]]
then
    kill_processes MEOW
    networksetup -setautoproxystate Wi-Fi off

    echo "autoproxy off"

elif [[ "$1" == "-cli" ]]
then
    export all_proxy=socks5://127.0.0.1:1081
    export http_proxy=http://127.0.0.1:8001
    export https_proxy=http://127.0.0.1:8001

    echo "cliproxy on"

    return

else
    echo "unknown option: "$1""
    echo "    usage: ~/MEOW.sh [-v2ray <command>] [-shadowsocks <command>] [-help] [-cow] [-cli]"
fi

exit
