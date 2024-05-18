#!/bin/bash
#
# xboard.sh
# https://github.com/9d84/xboard.sh

# 颜色输出
echo_content() {
    color=$1
    shift
    if [[ $TERM =~ ^screen.* ]]; then
        echo $@ # 不支持颜色的终端直接输出
    else
        case $color in # 支持颜色的终端使用颜色输出
        "red") printf "\033[31m%s\033[0m\n" "$@" ;;
        "sky_blue") printf "\033[1;36m%s\033[0m\n" "$@" ;;
        "green") printf "\033[32m%s\033[0m\n" "$@" ;;
        "white") printf "\033[37m%s\033[0m\n" "$@" ;;
        "magenta") printf "\033[31m%s\033[0m\n" "$@" ;;
        "yellow") printf "\033[33m%s\033[0m\n" "$@" ;;
        esac
    fi
}

# 检查当前用户是否为 root 用户
check_root() {
    [[ $(id -u) -eq 0 ]]
}

# 如果不是 root 用户，退出脚本
exit_if_not_root() {
    check_root || {
        echo "请用root权限运行此脚本" >&2
        exit 1
    }
}

# 检查依赖命令是否安装
check_depend() {
    # 需要检查的命令列表
    depends=("docker" "git")

    # 存储未找到的命令
    missing_depends=()

    # 检查每个命令是否存在
    for command in "${depends[@]}"; do
        command -v "$command" &>/dev/null || missing_depends+=("$command")
    done

    # 如果有命令未找到，则输出缺失的依赖信息并退出脚本
    if ((${#missing_depends[@]} > 0)); then
        echo_content red "缺少以下依赖:"
        printf -- '- %s\n' "${missing_depends[@]}"
        exit 1
    fi
}

#检查输入
check_format() {
    case $1 in
    "email")
        pattern="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$" 
        [[ $2 =~ $pattern ]] 
        ;;
    "domain_name") 
        pattern="^[A-Za-z0-9][A-Za-z0-9.-]{0,61}[A-Za-z0-9]\.[A-Za-z]{2,}$"
        [[ $2 =~ $pattern ]] 
        ;; 
     esac
}

#检查并安装脚本
check_xboard_directory() {
    xboard_DIR="/usr/local/etc/xboard.sh"
    xboard_SCRIPT="/usr/bin/xboard.sh"
    REPO_URL="https://github.com/ifkuan/xboard.sh"

    if [[ ! -d "$xboard_DIR" ]]; then
        echo_content yellow "xboard.sh 目录不存在，正在进行安装..."
        mkdir -p $xboard_DIR
        git clone "$REPO_URL" "$xboard_DIR"
        ln -s "$xboard_DIR/xboard.sh" "$xboard_SCRIPT"
        echo_content green "快捷方式安装成功！输入 xboard.sh 即可进入脚本。"
    fi
}

#防止重复安装
check_env_file() {
    ENV_FILE="/usr/local/etc/xboard.sh/www/.env"

    if [[ -f "$ENV_FILE" ]]; then
        echo_content yellow "您已安装过xboard"
        echo_content yellow "如果需要重新安装的，请rm -rf /usr/local/etc/xboard.sh再重装"
        echo_content yellow "如果需要更新xboard,请在菜单中选择"
        exit 1
    fi
}

# 初始化设置
init() {
    cd $xboard_DIR
    # 更新 git 子模块和重命名示例文件
    git submodule update --init
    git submodule update --remote
    find . -maxdepth 1 -type f -name "*.example" -exec bash -c 'newname="${1%.example}"; mv "$1" "$newname"' bash {} \;

    # 提示用户输入 mysql 密码
    mysql_password=$(get_user_input "请输入mysql密码（Enter生成随机密码）：")

    # 如果密码为空，则生成一个默认密码
    [[ -z $mysql_password ]] && mysql_password=$(openssl rand -base64 12 | tr '/' '_')

    # 提示用户输入 mysql 数据库名称
    mysql_database=$(get_user_input "请输入 mysql 数据库名称（默认为 xboard）:")

    # 如果数据库名称为空，则设置为默认名称 xboard
    [[ -z $mysql_database ]] && mysql_database="xboard"

    # 更新 .env 文件中的 mysql 密码和数据库名称
    sed -i "s/MYSQL_ROOT_PASSWORD =.*/MYSQL_ROOT_PASSWORD = $mysql_password/" .env
    sed -i "s/MYSQL_DATABASE =.*/MYSQL_DATABASE = $mysql_database/" .env
}

# 获取用户输入
get_user_input() {
    read -p $'\e[95m'"$1"$'\e[0m' response
    echo "$response"
}

# 询问用户是否需要绑定域名
# 询问用户是否需要绑定域名  
ask_domain_binding() {
    bind_domain=false
    response=$(get_user_input "是否需要绑定域名?(y/N): ")
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    [[ $response == "y" ]] && bind_domain=true && ask_domain_name
    echo $bind_domain
} 

# 询问用户要绑定的域名
ask_domain_name() {
    domain_name=$(get_user_input "请输入域名: ")
    domain_name=$(echo "$domain_name" | tr -d '[:space:]')
    replace_text_in_file "caddy.conf" ":80" "$domain_name"
}  

# 替换文件中的文本
replace_text_in_file() {
    file_path="$1"
    old_text="$2"
    new_text="$3"
    sed -i "s|$old_text|$new_text|g" "$file_path"
}

# 提示用户输入邮箱地址，并将邮箱地址添加到 caddy.conf 文件
email() {
    email=$(get_user_input "请输入您的邮箱地址:")  
    check_format "email" "$email" || {
        echo_content red "请输入有效的邮箱地址"
        exit 1 
    }
    sed -i "0,/{/ s/{/{\ntls ${email}/" caddy.conf
}

# 启动 xboard 相关服务
launch() {


install_date="xboard_install_$(date +%Y-%m-%d_%H:%M:%S).log"
printf "
\033[36m#######################################################################
#                     欢迎使用xboard一键部署脚本                     #
#                脚本适配环境CentOS7+/RetHot7+、内存1G+               #
#                更多信息请访问 https://gz1903.github.io              #
#######################################################################\033[0m
"
# 从接收信息后开始统计脚本执行时间
START_TIME=`date +%s`

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#                  正在关闭SElinux策略 请稍等~                        #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
setenforce 0
#临时关闭SElinux
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
#永久关闭SElinux

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#                  正在配置Firewall策略 请稍等~                       #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --reload
firewall-cmd --zone=public --list-ports
#放行TCP80、443端口


echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#                 正在下载安装包，时间较长 请稍等~                    #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
# 下载安装包
git clone https://gitee.com/gz1903/lnmp_rpm.git /usr/local/src/lnmp_rpm
cd /usr/local/src/lnmp_rpm
# 安装nginx，mysql，php，redis
echo -e "\033[36m下载完成，开始安装~\033[0m"
rpm -ivhU /usr/local/src/lnmp_rpm/*.rpm --nodeps --force --nosignature
 
# 启动nmp
systemctl start php-fpm.service mysqld redis

# 加入开机启动
systemctl enable php-fpm.service mysqld nginx redis

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#                    正在配置PHP.ini 请稍等~                          #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
sed -i "s/post_max_size = 8M/post_max_size = 32M/" /etc/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 600/" /etc/php.ini
sed -i "s/max_input_time = 60/max_input_time = 600/" /etc/php.ini
sed -i "s#;date.timezone =#date.timezone = Asia/Shanghai#" /etc/php.ini
# 配置php-sg11
mkdir -p /sg
wget -P /sg/  https://cdn.jsdelivr.net/gh/gz1903/sg11/Linux%2064-bit/ixed.7.3.lin
sed -i '$a\extension=/sg/ixed.7.3.lin' /etc/php.ini
#修改PHP配置文件
echo $?="PHP.inin配置完成完成"

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#                    正在配置Nginx 请稍等~                            #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
cp -i /etc/nginx/conf.d/default.conf{,.bak}
cat > /etc/nginx/conf.d/default.conf <<"eof"
server {
    listen       80;
    root /usr/share/nginx/html/xboard/public;
    index index.html index.htm index.php;

    error_page   500 502 503 504  /50x.html;
    #error_page   404 /404.html;
    #fastcgi_intercept_errors on;

    location / {
        try_files $uri $uri/ /index.php$is_args$query_string;
    }
    location = /50x.html {
        root   /usr/share/nginx/html/xboard/public;
    }
    #location = /404.html {
    #    root   /usr/share/nginx/html/xboard/public;
    #}
    location ~ \.php$ {
        root           html;
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  /usr/share/nginx/html/xboard/public/$fastcgi_script_name;
        include        fastcgi_params;
    }
    location /downloads {
    }
    location ~ .*\.(js|css)?$
    {
        expires      1h;
        error_log off;
        access_log /dev/null;
    }
}
eof

cat > /etc/nginx/nginx.conf <<"eon"

user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    #fastcgi_intercept_errors on;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
eon

mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/xboard.conf

# 创建php测试文件
touch /usr/share/nginx/html/phpinfo.php
cat > /usr/share/nginx/html/phpinfo.php <<eos
<?php
	phpinfo();
?>
eos

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#                    正在部署xboard 请稍等~                          #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
rm -rf /usr/share/nginx/html/xboard
cd /usr/share/nginx/html
git clone https://github.com/cedar2025/xboard.git
cd /usr/share/nginx/html/xboard
echo -e "\033[36m请输入y确认安装： \033[0m"

    echo_content sky_blue "请在下方输入相关信息"
    echo "
数据库地址： mysql
数据库名: $mysql_database
数据库用户名: root
数据库密码: $mysql_password
"

sh /usr/share/nginx/html/xboard/init.sh
git clone https://gitee.com/gz1903/xboard-theme-LuFly.git /usr/share/nginx/html/xboard/public/LuFly
mv /usr/share/nginx/html/xboard/public/LuFly/* /usr/share/nginx/html/xboard/public/
chmod -R 777 /usr/share/nginx/html/xboard
# 添加定时任务
echo "* * * * * root /usr/bin/php /usr/share/nginx/html/xboard/artisan schedule:run >/dev/null 2>/dev/null &" >> /etc/crontab
# 安装Node.js
curl -sL https://rpm.nodesource.com/setup_10.x | bash -
yum -y install nodejs
npm install -g n
n 17
node -v
# 安装pm2
npm install -g pm2
# 添加守护队列
pm2 start /usr/share/nginx/html/xboard/pm2.yaml --name xboard
# 保存现有列表数据，开机后会自动加载已保存的应用列表进行启动
pm2 save
# 设置开机启动
pm2 startup

#获取主机内网ip
ip="$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')"
#获取主机外网ip
ips="$(curl ip.sb)"

systemctl restart php-fpm mysqld redis && nginx
echo $?="服务启动完成"
# 清除缓存垃圾
rm -rf /usr/local/src/xboard_install
rm -rf /usr/local/src/lnmp_rpm
rm -rf /usr/share/nginx/html/xboard/public/LuFly

# xboard安装完成时间统计
END_TIME=`date +%s`
EXECUTING_TIME=`expr $END_TIME - $START_TIME`
echo -e "\033[36m本次安装使用了$EXECUTING_TIME S!\033[0m"

echo -e "\033[32m--------------------------- 安装已完成 ---------------------------\033[0m"
echo -e "\033[32m##################################################################\033[0m"
echo -e "\033[32m#                            xboard                             #\033[0m"
echo -e "\033[32m##################################################################\033[0m"
echo -e "\033[32m 数据库用户名   :root\033[0m"
echo -e "\033[32m 数据库密码     :"$Database_Password
echo -e "\033[32m 网站目录       :/usr/share/nginx/html/xboard \033[0m"
echo -e "\033[32m Nginx配置文件  :/etc/nginx/conf.d/xboard.conf \033[0m"
echo -e "\033[32m PHP配置目录    :/etc/php.ini \033[0m"
echo -e "\033[32m 内网访问       :http://"$ip
echo -e "\033[32m 外网访问       :http://"$ips
echo -e "\033[32m 安装日志文件   :/var/log/"$install_date
echo -e "\033[32m------------------------------------------------------------------\033[0m"
echo -e "\033[32m 如果安装有问题请反馈安装日志文件。\033[0m"
echo -e "\033[32m 使用有问题请在这里寻求帮助:https://gz1903.github.io\033[0m"
echo -e "\033[32m 电子邮箱:xboard@qq.com\033[0m"
echo -e "\033[32m------------------------------------------------------------------\033[0m"

    



    echo_content green "配置文件位于$xboard_DIR"

}

# 更新 xboard
update_xboard() {
    echo_content sky_blue "正在更新 xboard..."
    cd $xboard_DIR
    docker compose exec www bash -c "apk add git && rm -rf ./.git* && git init && git remote add origin https://github.com/cedar2025/xboard.git && bash ./update.sh"    
}

#更新脚本
update_script() {
    echo_content sky_blue "正在更新脚本..."
    wget -O "$xboard_DIR/xboard.sh" "https://raw.githubusercontent.com/ifkuan/xboard.sh/master/xboard.sh"
    chmod +x "$xboard_SCRIPT"
    echo_content green "脚本更新完成！"
}

# 主菜单
show_menu() {
    echo_content sky_blue "请选择要执行的操作:"
    echo "[1] 安装 xboard"
    echo "[2] 更新脚本"
    echo "[3] 更新 xboard"
    echo "[Q] 退出"
}

handle_error() {
    echo_content red "$1"
}

# 主函数
main() {
    exit_if_not_root
    check_depend
    check_xboard_directory

    while true; do
        show_menu

        read -p "请选择操作: " choice

        case $choice in
        1)
            check_env_file
            init
            if ask_domain_binding; then
                email
            fi
            launch
            ;;
        2)
            update_script
            ;;
        3)
            update_xboard
            ;;
        [Qq])
            break
            ;;
        *)
           handle_error "无效的选择,请重新输入."  # 错误处理
            ;;
        esac

        echo
    done
}


# 调用主函数
main
