#!/bin/bash

#set -x -e

function findContentProvider(){
    authorities=$1

    succ=false
    tmpFile=`tempfile`
    adb shell pm dump "*" > $tmpFile

    for auth in ${authorities[@]}
    do
        echo "查找目标: $auth"
        quickSearch=`grep $auth $tmpFile`
        if [ -z "$quickSearch" ];then
            continue
        fi

        findSection=false
        findAuth=false

        ln=0
        while read line
        do
            let ln++
#        echo "$findAuth, $findSection, ${#line}, $line"
            if [ ${#line} -eq 1 ];then
                if [ $findSection = true ] || [ $findAuth = true ];then
                    break
                fi
            elif [ "${line#"ContentProvider Authorities"}" != "${line}" ];then
                findSection=true
            fi
            if [ $findAuth = true ] && [ "${line#"applicationInfo=ApplicationInfo"}" != "${line}" ];then
                pak=`echo $line | awk -F '{|}| ' '{print $3}'`
                echo "Find conflict package!! , $pak"
                succ=true
                break
            elif [ $findSection = true ];then
                _auth=`echo $line | grep -E "\[.*\]"`
                if [ ! -z "$_auth" ];then
                    _auth=${_auth:1:-3}
                    if [ "$_auth" == "$auth" ];then
                        findAuth=true
                    fi
                fi
            fi
        done < $tmpFile
        if [ $succ = true ];then
            break
        fi
    done

    if [ -a $tmpFile ];then
        rm $tmpFile
    fi
    if [ $succ = true ];then
        return 0
    else
        return 1
    fi
}

tmpFile=`tempfile`
if [ $# != 1 ];then
    echo "Usage: $0 xxx.apk"
    exit -1
else
    succ=false
    authorities=()
    aapt dump xmltree "$1" AndroidManifest.xml > $tmpFile
    index=0
    while read line
    do
        if [[ "$line" == *android\:authorities* ]];then
            auth=`echo $line | awk -F '"' '{print $2}'`
            authorities[$index]=$auth
            let index=index+1
        fi
    done < $tmpFile
    if [ -a $tmpFile ];then
        rm $tmpFile
    fi

    findContentProvider $authorities
    funCode=$?
    if [ $funCode -eq 0 ];then
        succ=true
    fi

    if [ $succ = false ];then
        echo Not Found conflict provider
    fi
fi
