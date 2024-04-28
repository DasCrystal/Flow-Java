# !/bin/sh

if [ $# == 0 ]
then

    echo "# Usage"
    echo "flow-spigotplugin <operate!> <projectname?>"
    
    echo "# 中文"
    echo "create - 在 . 建立一個名為 <projectname?> 的資料夾，並在其中建立開發插件的基本結構"
    echo "pack   - 把 ./src/*.java 檔案編譯成 ./pkg/*.class 並且將其包裝成 (工作目錄名稱).jar"
    echo "load   - 將 (工作目錄名稱).jar 載入到 ../_Env/plugins 內"
    echo "pandl  - 相等於 'flow-spigotplugin pack & flow-spigotplugin load'"
    echo "clear  - 刪除 ../pkg/code"
    echo "pandlRemo <User@Server> <port> <path> - 將結果上傳到指定的 SFTP 伺服器，必須預先 export SSHPASS 環境變數。"

    echo "# English"
    echo "create - Create a dir named <projectname?>, and add the basic struct for plugin development in it."
    echo "pack   - Compile ./src/*.java to ./pkg/*.class and package them to (pwd).jar"
    echo "load   - Load (pwd).jar into ../_Env/plugins"
    echo "pandl  - Equals 'flow-spigotplugin pack & flow-spigotplugin load'"
    echo "clear  - Clear contnet of ../_Env/plungins"
    
fi

# Define the name of project (using folder name)
project=$(basename $(pwd))

# Define the server environment
env=../_Env

function create() {

    name=$1

    mkdir $1
    cd $1

    mkdir ./lib
    cp ../_Lib/* ./lib

    mkdir ./src
    cd ./src

        
    echo "\
package code;

import org.bukkit.plugin.java.JavaPlugin;

public class $1 extends JavaPlugin
{
    public void onEnable()
    {
        Util.f(\"Hello, World\");
    }
}

" > ${name}.java

    echo "\
package code;

import org.bukkit.Server;
import org.bukkit.plugin.PluginManager;
import org.bukkit.plugin.java.JavaPlugin;

import java.util.logging.Level;
import java.util.logging.Logger;

public class Util
{
    public static final JavaPlugin plugin = ${name}.getPlugin(${name}.class);
    public static final Server server = plugin.getServer();
    public static final Logger logger = server.getLogger();
    public static final PluginManager manager = server.getPluginManager();

    public static void f(String m)
    {Util.logger.log(Level.INFO, \"-|\" + m + \"|-\");}
    
    public static void fw(String m)
    {Util.logger.log(Level.WARNING, \"-|\" + m + \"|-\");}
    
    public static void fe(String m)
    {Util.logger.log(Level.SEVERE, \"-|\" + m + \"|-\");}
}

" > Util.java

    cd ..

# manifest.mf
    echo "\
Manifest-Version: 1.0
Created-By: Flow
" > manifest.mf

    mkdir ./pkg
    cd ./pkg


    echo "\
name: $1
main: code.$1
version: 0.0.0
description: Nothing here yet.
author: 
api-version: 1.13

folia-supported: true

commands:

  $1:
    aliases: []
    description: No description yet.
    usage: Nope, no usage here. No.
    
" > plugin.yml

cd ..

echo "[INFO] Don't forget to modify plugin.yml."

}

function pack() {
    
    mkdir .flow 2> /dev/null

    # Build number part
    if [ -f ./.flow/BuildNumber ]
    then
        BUILD_NUMBER=`cat ./.flow/BuildNumber`
    else
        BUILD_NUMBER=-1
    fi

    BUILD_NUMBER=`expr ${BUILD_NUMBER} + 1`

    JAR_NAME="${project}.${BUILD_NUMBER}.jar"

    echo "-|Packing sources to ${JAR_NAME}|-"

    # *.java -> *.class
    javac -d "./pkg" -cp "./lib/*:." `find ./src -name "*.java"`

    if [ $? != 0 ]
    then
        exit
    fi

    rm ./${project}.*.jar 2> /dev/null

    # *.class -> `pwd`.jar (*.class + manifest.mf + plugin.yml)
    cd ./pkg
    jar mcf "../manifest.mf" ../${JAR_NAME} `find ./*`
    
    if [ $? != 0 ]
    then
        exit
    fi
    cd ..

    printf ${BUILD_NUMBER} > ./.flow/BuildNumber 
}

function packNms()
{

    if [ "$2" == "" ] || [ "$3" != "" ]
    then

        echo "Usage: packNms <SpecialSourceVersion> <NmsPackageVersion>"
        echo "Examp: packNms 1.10.0 1.17-R0.1-SNAPSHOT"
        exit

    fi
    
    pack

    echo "-|Dealing with NMS remapping|-"

    echo "Using: $HOME/.m2/repository/net/md-5/SpecialSource/$1/SpecialSource-$1-shaded.jar"
    echo "Using: $HOME/.m2/repository/org/spigotmc/spigot/$2/spigot-$2-remapped-mojang.jar"

    java -cp "$HOME/.m2/repository/net/md-5/SpecialSource/$1/SpecialSource-$1-shaded.jar:$HOME/.m2/repository/org/spigotmc/spigot/$2/spigot-$2-remapped-mojang.jar" net.md_5.specialsource.SpecialSource --live -i ${project}.jar -o ${project}-obf.jar -m $HOME/.m2/repository/org/spigotmc/minecraft-server/$2/minecraft-server-$2-maps-mojang.txt --reverse
    
    if [ $? != 0 ]
    then
        exit
    fi

    java -cp "$HOME/.m2/repository/net/md-5/SpecialSource/$1/SpecialSource-$1-shaded.jar:$HOME/.m2/repository/org/spigotmc/spigot/$2/spigot-$2-remapped-obf.jar" net.md_5.specialsource.SpecialSource --live -i ${project}-obf.jar -o ${project}.jar -m $HOME/.m2/repository/org/spigotmc/minecraft-server/$2/minecraft-server-$2-maps-spigot.csrg

    if [ $? != 0 ]
    then
        exit
    fi
    
    rm ${project}-obf.jar
    
}

function load() {

    echo "-|Loading ${JAR_NAME} to server|-"

    rm ${env}/plugins/${project}.*.jar 2> /dev/null
    mkdir ${env}/plugins 2> /dev/null

    cp ./${JAR_NAME} ${env}/plugins

}

function loadRemo()
{

    # UserServer
    us=$1
    # Port
    port=$2
    # Path
    path=$3

    # File to Put
    file=./${project}.jar

    fullReq="-P ${port} ${us}:${path}"
    
    echo "-|Putting ${file} to ${us}:${port} -> ${path} |-"

    # Password field is different, it must form keyboard (at default).

    sshpass -e sftp ${fullReq} << !
    put ${file}
    exit
!

}

function pandl() {

    pack
    load

}

function pandlNms()
{

    packNms $@
    load
    
}

function pandlRemo()
{

    pack
    loadRemo $@

}

function clear() {

    echo "-|Clearing packed jar file in the projectdir and server|-"

    rm -r ./${project}.jar
    rm -r ./pkg/code

}

function run()
{
    echo "-|Execute server.jar|-"

    cd ${env}

    serverjar="`find ./*.jar`"
    
    serverjar=( ${serverjar} )
    serverjar=${serverjar[0]}

    if [ " $@" == " " ]
    then
        COMMAND_LINE="java -Xmx8G -jar ${serverjar[0]}"
    else
        COMMAND_LINE="java -Xmx8G -jar ${serverjar[0]} $@"
    fi
    

    printf "${COMMAND_LINE}" > ./.CurrentRunning

    # Only for plugin debug, not for product environment. 
    ${COMMAND_LINE}
}

function stop()
{
    CURRENT_RUNNING="${env}/.CurrentRunning"

    if [ -f ${CURRENT_RUNNING} ]
    then
        COMMAND_LINE=`cat ${CURRENT_RUNNING}`
        kill `pgrep -f "${COMMAND_LINE}"`
        rm ${CURRENT_RUNNING}
    fi
}

function restart()
{
    stop && run
}

function pls()
{
    pack && load && stop
}

function runloop()
{
    while [ true ]
    do
        run
        
        STOP_SIGNAL="${env}/.ShouldStopNow"

        if [ ! -f ${STOP_SIGNAL} ]
        then
            continue
        fi

        rm ${env}/.ShouldStopNow
        break
    done
}

function endloop()
{
    STOP_SIGNAL="${env}/.ShouldStopNow"
    touch ${STOP_SIGNAL}

    stop
}

function runwithaikar() {

    echo "-|Execute server.jar with aiker's flags|-"

    cd ${env}

    serverjar="`find ./*.jar`"
    
    serverjar=( ${serverjar} )
    serverjar=${serverjar[0]}

    # Only for plugin debug.
    java -Xms2G -Xmx2G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar ${serverjar[0]}
    
}

function runanw()
{

    rm `find ${env}/*/session.lock`
    run

}

#check command

grep "function $1()" $0 > /dev/null

if [ $? == 0 ]
then

    echo "-|Task started at `date`|-"
    
    $@

    echo "-|Task Compelete|-"

else

echo "[ERRO] Invaild command \"$1\"."

exit 1

fi


