#!/usr/bin/env bash

# NETWORK
PROXY="$1"

# COLOR SCHEMA
COLOR_HINT=36m
COLOR_WARNING=31m

# DIRECTORY
BASE_PATH=/usr/local/share/
DOTNET_SAVE_PATH=${BASE_PATH}dotnet/
ASF_SAVE_PATH=${BASE_PATH}asf/
ASF_LOG_FILE=${ASF_SAVE_PATH}log.txt
ASF_EXEC_FILE=${ASF_SAVE_PATH}ArchiSteamFarm.sh
ASF_BOT_CONFIG_FILE=${ASF_SAVE_PATH}config/bot.json
ASF_GLOCAL_CONFIG_FILE=${ASF_SAVE_PATH}config/ASF.json

# REQUIREMENTS
REQUIREMENTS=(tar unzip curl)

# OUTPUT FORMAT
function highlight() {
    echo -e "\033[$2$1\033[0m"
}

function hint() {
    highlight "$1" $COLOR_HINT
}

function warning() {
    highlight "$1" $COLOR_WARNING
}

# INSTALLATION
function create_directories() {
    mkdir -p $BASE_PATH
    mkdir -p $DOTNET_SAVE_PATH
    mkdir -p $ASF_SAVE_PATH
}

function install_requirements() {
    system_apt=$(command -v yum)
    if [[ ! $apt ]]; then
        system_apt=$(command -v apt)
    fi
    for software in ${REQUIREMENTS[@]}; do
        if [[ ! $(command -v $software) ]]; then
            eval $system_apt install -y $software
        fi
    done
}

function dotnet_error() {
    echo -e $(warning "$1")，请访问 $(hint https://bit.ly/2KsGxGm) 查看详细信息
}

function install() {
    if [[ ! $(command -v systemctl) ]]; then
        echo -e $(warning 不支持的系统版本)，请前往 $(hint https://github.com/JustArchiNET) 查看详细信息
        return 1
    fi

    if [[ $(dotnet --info 2>/dev/null) ]] && [[ -f $ASF_EXEC_FILE ]]; then
        warning '程序已经安装，3s 回到主菜单'
        sleep 3
        return 0
    fi

    install_requirements
    create_directories

    # INSTALL .NET CORE SDK 3.0
    arch=$(uname -m)
    if [[ $arch == x86_64 ]]; then
        version=x64
    elif [[ "$arch" == *"armv7"* ]] || [[ "$arch" == "armv6l" ]]; then
        version=arm32
    elif [[ "$arch" == *"armv8"* ]] || [[ "$arch" == "aarch64" ]]; then
        version=arm64
    else
        dotnet_error "不支持的系统架构：$arch"
        return 1
    fi
    version=dotnet-sdk-3.0.100-linux-$version
    dotnet_uri=https://dotnet.microsoft.com/download/thank-you/$version-binaries
    dotnet_uri=$(curl -sL -m 5 $dotnet_uri | grep -oE "http.+$version.tar.gz" | head -1)
    if [[ ! $dotnet_uri ]]; then
        dotnet_error "无法获取 .NET Core 3.0 SDK 下载地址"
        return 1
    fi

    hint "正在下载 .NET Core 3.0 SDK"
    curl -L $dotnet_uri -o ${DOTNET_SAVE_PATH}$version.tar.gz
    if [[ -f ${DOTNET_SAVE_PATH}$version.tar.gz ]]; then
        tar -zxf ${DOTNET_SAVE_PATH}$version.tar.gz -C $DOTNET_SAVE_PATH
    else
        dotnet_error "无法下载 .NET Core 3.0 SDK"
        return 1
    fi
    if [[ -f $DOTNET_SAVE_PATH/dotnet ]]; then
        ln -s $DOTNET_SAVE_PATH/dotnet /usr/local/bin/dotnet
        if [[ ! $(dotnet --info 2>/dev/null) ]]; then
            dotnet_error ".NET Core 3.0 SDK 版本错误"
            return 1
        fi
    else
        dotnet_error "无法下载 .NET Core 3.0 SDK"
        return 1
    fi

    # INSTALL ASF
    hint "正在下载 ASF 主程序"
    asf_uri=https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/5.2.1.5/ASF-generic.zip
    if [[ $PROXY ]]; then
        curl -x $PROXY -L $asf_uri -o ${ASF_SAVE_PATH}ASF-generic.zip
    else
        curl -L $asf_uri -o ${ASF_SAVE_PATH}ASF-generic.zip
    fi

    unzip ${ASF_SAVE_PATH}ASF-generic.zip -d $ASF_SAVE_PATH
    if [[ -f $ASF_EXEC_FILE ]]; then
        chmod +x $ASF_EXEC_FILE
        cat >/etc/systemd/system/asf.service <<EOF
[Unit]
Description=ArchiSteamFarm
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=$ASF_EXEC_FILE

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
    else
        echo $(warning '无法下载 ASF')，请前往 $(hint https://github.com/JustArchiNET) 查看详细信息
        return 1
    fi
    hint '安装完成，3s 回到主菜单'
    sleep 3
}

function uninstall() {
    if [[ ! -f /etc/systemd/system/asf.service ]]; then
        warning '程序尚未安装，3s 回到主菜单'
        sleep 3
        return 0
    fi
    files=(
        $DOTNET_SAVE_PATH
        $ASF_SAVE_PATH
        /usr/local/bin/dotnet
        /etc/systemd/system/asf.service
    )
    for file in ${files[@]}; do
        rm -rf $file
    done
    systemctl daemon-reload
    hint 卸载完成
    return 1
}

function auto_start() {
    if [[ ! -f /etc/systemd/system/asf.service ]]; then
        warning '程序尚未安装，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ ! -f $ASF_BOT_CONFIG_FILE ]]; then
        warning '无配置文件，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ $1 == add ]]; then
        systemctl enable asf
        hint '已添加开机自启，3s 回到主菜单'
    else
        systemctl disable asf
        hint '已取消开机自启，3s 回到主菜单'
    fi
    sleep 3
}

# CORE FUNCTIONS
function is_started() {
    [[ $(systemctl is-active asf) == active ]] && echo true
}

function status() {
    if [[ ! -f /etc/systemd/system/asf.service ]]; then
        warning '程序尚未安装，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ ! -f $ASF_LOG_FILE ]] || [[ ! -s $ASF_LOG_FILE ]]; then
        warning '尚无日志，3s 回到主菜单'
        sleep 3
        return 0
    fi
    state=$(systemctl is-active asf)
    [[ $state == active ]] && output=hint || output=warning
    echo -ne "程序运行状态: $($output $state)，\
查看完毕后请按 $(hint 'Ctrl + C') 退出日志系统，现在请按任意键继续"
    read
    watch -d -n 1 cat $ASF_LOG_FILE
    # journalctl -u steam --since today -f
}

function config() {
    if [[ ! -f /etc/systemd/system/asf.service ]]; then
        warning '程序尚未安装，3s 回到主菜单'
        sleep 3
        return 0
    fi
    config=$ASF_BOT_CONFIG_FILE
    web_uri=https://bit.ly/32R1ykf
    notice_enabled="注意勾选 $(hint Enabled)，"
    if [[ $1 == global ]]; then
        config=$ASF_GLOCAL_CONFIG_FILE
        web_uri=https://bit.ly/2XoWMJU
        notice_enabled=''
    fi
    if [[ $(is_started) ]]; then
        warning '程序正在运行，请先停止，3s 回到主菜单'
        sleep 3
        return 0
    fi
    echo -e "请打开 $(hint $web_uri)，\
生成 $(hint V5.2.1.5) 版本可用配置，$notice_enabled随后 $(hint 右键) 粘贴到此处，按 $(hint 'Enter -> Ctrl + D') 保存"
    [[ -s $config ]] && cp $config $config.bak
    cat >$config
    hint '配置完成，3s 回到主菜单'
    sleep 3
}

function 2auth() {
    if [[ ! -f /etc/systemd/system/asf.service ]]; then
        warning '程序尚未安装，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ ! -f $ASF_BOT_CONFIG_FILE ]]; then
        warning '无配置文件，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ $(is_started) ]]; then
        warning '程序正在运行，请先停止，3s 回到主菜单'
        sleep 3
        return 0
    fi
    echo -ne "两步验证通过后请按 $(hint 'Ctrl + C') 退出，\
随后执行 $(hint 'steam -> 3. 运行')，现在请按任意键继续"
    read
    bash $ASF_EXEC_FILE
}

function start() {
    if [[ ! -f /etc/systemd/system/asf.service ]]; then
        warning '程序尚未安装，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ ! -f $ASF_BOT_CONFIG_FILE ]]; then
        warning '无配置文件，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ $(is_started) ]]; then
        warning '程序已经启动，3s 回到主菜单'
        sleep 3
        return 0
    fi
    systemctl start asf
    hint '启动成功，3s 回到主菜单'
    sleep 3
}

function stop() {
    if [[ ! -f /etc/systemd/system/asf.service ]]; then
        warning '程序尚未安装，3s 回到主菜单'
        sleep 3
        return 0
    fi
    if [[ ! $(is_started) ]]; then
        warning '程序尚未运行，3s 回到主菜单'
        sleep 3
        return 0
    fi
    systemctl stop asf
    hint '停止成功，3s 回到主菜单'
    sleep 3
}

# MENU
function menu() {
    content=$(
        cat <<EOF
----------------------
    $(hint ASF) 挂卡管理器
     V0.0.1 2019.11.16
           AUTHOR $(hint LOGI)
           MODIFY $(hint deXaint)
----------------------
 0. $(hint 退出)
 1. $(hint 安装)
 2. $(hint 卸载)
 3. $(hint 运行)
 4. $(hint 停止)
 5. $(hint 状态)
 6. $(hint 全局配置)
 7. $(hint 'BOT 配置')
 8. $(hint 两步验证)
 9. $(hint 开机自启)
10. $(hint 取消开机自启)
----------------------
请选择：
EOF
    )
    while true; do
        clear
        echo -ne "$content"
        read option
        clear
        case $option in
        0)
            exit
            ;;
        1)
            install
            ;;
        2)
            uninstall
            ;;
        3)
            start
            ;;
        4)
            stop
            ;;
        5)
            status
            ;;
        6)
            config global
            ;;
        7)
            config bot
            ;;
        8)
            2auth
            ;;
        9)
            auto_start add
            ;;
        10)
            auto_start remove
            ;;
        *) ;;
        esac
        [[ $? -eq 1 ]] && exit
        menu
    done
}

menu
