# xboard.sh

xboard全自动安装

## 用法
 
 sudo yum install dnf git php8.2
 
 sudo apt-get install dnf git php8.2
 
sudo yum purge apache2

sudo apt-get purge apache2

1. 安装依赖
```bash
dnf install  git curl -y||(apt update -y &&  apt install git curl -y) && bash -c "$(curl -fsSL https://get.docker.com)"
```

2. 使用脚本

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/ifkuan/xboard.sh/master/xboard.sh)"
```
