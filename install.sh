#!/bin/bash

# 脚本名称：Docker 服务部署脚本（定制媒体库版）
# 作者：pdd520
# 脚本仓库：https://github.com/pdd520/pdd520

# --- 定义默认变量 ---
# 端口变量
DEFAULT_PORTTAINER_PORT=9000
DEFAULT_FILEBROWSER_PORT=1234
DEFAULT_QBITTORRENT_WEBUI_PORT=8080
DEFAULT_QBITTORRENT_PEER_PORT=6881
DEFAULT_EMBY_PORT=8096
DEFAULT_EMBY_HTTPS_PORT=8920
DEFAULT_MOVIEPILOT_PORT=3000
DEFAULT_COOKIECLOUD_PORT=8088

# 媒体库目录结构
MEDIA_DOWNLOADS_DIR="downloads"
MEDIA_MOVIES_DIR="电影"
MEDIA_TVSHOWS_DIR="电视剧"
MEDIA_SUBDIRS=("华语电影" "外语电影" "国产剧" "欧美剧" "日韩剧")

# 其他变量
DEFAULT_TZ="Asia/Shanghai"
DEFAULT_PROXY="http://192.168.1.2:7890"
DEFAULT_SUPERUSER="skywrt"
DEFAULT_API_TOKEN="G*Z@tNyp8d8MO2%V@@"

echo "========================================="
echo "  Docker 服务一键部署脚本（定制媒体库版）"
echo "========================================="

# 脚本所在目录将作为所有文件的根目录
DEPLOY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOCKER_BASE_DIR="$DEPLOY_DIR/docker"
MEDIA_BASE_DIR="$DEPLOY_DIR/media"

# --- 交互式输入 ---

# 1. 输入端口映射
read -p "请输入 Portainer 的宿主机端口 [默认: $DEFAULT_PORTTAINER_PORT]: " PORTTAINER_PORT
PORTTAINER_PORT=${PORTTAINER_PORT:-$DEFAULT_PORTTAINER_PORT}

read -p "请输入 Filebrowser 的宿主机端口 [默认: $DEFAULT_FILEBROWSER_PORT]: " FILEBROWSER_PORT
FILEBROWSER_PORT=${FILEBROWSER_PORT:-$DEFAULT_FILEBROWSER_PORT}

read -p "请输入 Qbittorrent 的 Web UI 宿主机端口 [默认: $DEFAULT_QBITTORRENT_WEBUI_PORT]: " QBITTORRENT_WEBUI_PORT
QBITTORRENT_WEBUI_PORT=${QBITTORRENT_WEBUI_PORT:-$DEFAULT_QBITTORRENT_WEBUI_PORT}

read -p "请输入 Qbittorrent 的对等端口 [默认: $DEFAULT_QBITTORRENT_PEER_PORT]: " QBITTORRENT_PEER_PORT
QBITTORRENT_PEER_PORT=${QBITTORRENT_PEER_PORT:-$DEFAULT_QBITTORRENT_PEER_PORT}

read -p "请输入 Emby 的宿主机端口 [默认: $DEFAULT_EMBY_PORT]: " EMBY_PORT
EMBY_PORT=${EMBY_PORT:-$DEFAULT_EMBY_PORT}

read -p "请输入 Emby 的 HTTPS 端口 [默认: $DEFAULT_EMBY_HTTPS_PORT]: " EMBY_HTTPS_PORT
EMBY_HTTPS_PORT=${EMBY_HTTPS_PORT:-$DEFAULT_EMBY_HTTPS_PORT}

read -p "请输入 MoviePilot 的宿主机端口 [默认: $DEFAULT_MOVIEPILOT_PORT]: " MOVIEPILOT_PORT
MOVIEPILOT_PORT=${MOVIEPILOT_PORT:-$DEFAULT_MOVIEPILOT_PORT}

read -p "请输入 CookieCloud 的宿主机端口 [默认: $DEFAULT_COOKIECLOUD_PORT]: " COOKIECLOUD_PORT
COOKIECLOUD_PORT=${COOKIECLOUD_PORT:-$DEFAULT_COOKIECLOUD_PORT}

# 2. 输入 PUID 和 PGID
echo -e "\n--- 获取 PUID 和 PGID ---"
echo "你可以通过在终端运行 'id <你的用户名>' 命令来获取。"
read -p "请输入用户的 PUID (例如: 1026): " PUID
while ! [[ "$PUID" =~ ^[0-9]+$ ]]
do
  read -p "PUID 必须是数字，请重新输入: " PUID
done

read -p "请输入用户的 PGID (例如: 100): " PGID
while ! [[ "$PGID" =~ ^[0-9]+$ ]]
do
  read -p "PGID 必须是数字，请重新输入: " PGID
done

# --- 部署步骤 ---

echo -e "\n========================================="
echo "         正在生成并部署服务..."
echo "========================================="

# 自动创建所有需要的子目录
QBITTORRENT_CONFIG_DIR="$DOCKER_BASE_DIR/qbittorrent"
PORTTAINER_CONFIG_DIR="$DOCKER_BASE_DIR/portainer"
FILEBROWSER_CONFIG_DIR="$DOCKER_BASE_DIR/filebrowser"
EMBY_CONFIG_DIR="$DOCKER_BASE_DIR/emby"
MOVIEPILOT_CONFIG_DIR="$DOCKER_BASE_DIR/moviepilot"
COOKIECLOUD_CONFIG_DIR="$DOCKER_BASE_DIR/cookiecloud"

# 创建配置目录
echo "正在创建配置目录..."
for dir in "$QBITTORRENT_CONFIG_DIR" "$PORTTAINER_CONFIG_DIR" "$FILEBROWSER_CONFIG_DIR" \
           "$EMBY_CONFIG_DIR" "$MOVIEPILOT_CONFIG_DIR" "$COOKIECLOUD_CONFIG_DIR"; do
    if [ ! -d "$dir" ]; then
        echo "创建目录 $dir..."
        mkdir -p "$dir" || { echo "错误: 无法创建目录 $dir。请检查权限。"; exit 1; }
        chown $PUID:$PGID "$dir" || echo "警告: 无法更改目录 $dir 的所有权。"
    fi
done

# 创建媒体库目录结构
echo "正在创建媒体库目录结构..."
MEDIA_DOWNLOADS_PATH="$MEDIA_BASE_DIR/$MEDIA_DOWNLOADS_DIR"
MEDIA_MOVIES_PATH="$MEDIA_BASE_DIR/$MEDIA_MOVIES_DIR"
MEDIA_TVSHOWS_PATH="$MEDIA_BASE_DIR/$MEDIA_TVSHOWS_DIR"

# 创建主目录
for dir in "$MEDIA_BASE_DIR" "$MEDIA_DOWNLOADS_PATH" "$MEDIA_MOVIES_PATH" "$MEDIA_TVSHOWS_PATH"; do
    if [ ! -d "$dir" ]; then
        echo "创建目录 $dir..."
        mkdir -p "$dir" || { echo "错误: 无法创建目录 $dir。请检查权限。"; exit 1; }
        chown $PUID:$PGID "$dir" || echo "警告: 无法更改目录 $dir 的所有权。"
    fi
done

# 创建子目录
echo "正在创建分类子目录..."
for subdir in "${MEDIA_SUBDIRS[@]}"; do
    # 在downloads下创建所有子目录
    dir="$MEDIA_DOWNLOADS_PATH/$subdir"
    if [ ! -d "$dir" ]; then
        echo "创建目录 $dir..."
        mkdir -p "$dir" || { echo "错误: 无法创建目录 $dir。请检查权限。"; exit 1; }
        chown $PUID:$PGID "$dir" || echo "警告: 无法更改目录 $dir 的所有权。"
    fi
    
    # 在电影目录下只创建电影类子目录
    if [[ "$subdir" == *"电影"* ]]; then
        dir="$MEDIA_MOVIES_PATH/$subdir"
        if [ ! -d "$dir" ]; then
            echo "创建目录 $dir..."
            mkdir -p "$dir" || { echo "错误: 无法创建目录 $dir。请检查权限。"; exit 1; }
            chown $PUID:$PGID "$dir" || echo "警告: 无法更改目录 $dir 的所有权。"
        fi
    fi
    
    # 在电视剧目录下只创建剧集类子目录
    if [[ "$subdir" == *"剧"* ]]; then
        dir="$MEDIA_TVSHOWS_PATH/$subdir"
        if [ ! -d "$dir" ]; then
            echo "创建目录 $dir..."
            mkdir -p "$dir" || { echo "错误: 无法创建目录 $dir。请检查权限。"; exit 1; }
            chown $PUID:$PGID "$dir" || echo "警告: 无法更改目录 $dir 的所有权。"
        fi
    fi
done

# --- 移除旧容器，以防冲突 ---
echo "检查并移除旧容器..."
docker rm -f portainer-zh filebrowser qbittorrent Emby moviePilot cookiecloud watchtower &>/dev/null

# 1. 部署 Portainer
echo "正在拉取 Portainer 镜像..."
docker pull ysx88/portainer-ce || { echo "错误: 无法拉取 Portainer 镜像，请检查网络。"; exit 1; }
echo "正在部署 Portainer 容器..."
docker run -d \
  --name=portainer-zh \
  --restart=always \
  -p $PORTTAINER_PORT:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ysx88/portainer-ce

# 2. 部署 Filebrowser
echo "正在拉取 Filebrowser 镜像..."
docker pull ysx88/filebrowser:latest || { echo "错误: 无法拉取 Filebrowser 镜像，请检查网络。"; exit 1; }
echo "正在部署 Filebrowser 容器..."
docker run -d \
  --name=filebrowser \
  --restart=always \
  -p $FILEBROWSER_PORT:80 \
  -e PUID=$PUID \
  -e PGID=$PGID \
  -e TZ=$DEFAULT_TZ \
  -v $MEDIA_BASE_DIR:/srv/media \
  -v /:/srv/system \
  -v $FILEBROWSER_CONFIG_DIR/config/config.json:/etc/config.json \
  -v $FILEBROWSER_CONFIG_DIR/data/database.db:/etc/database.db \
  ysx88/filebrowser:latest

# 3. 部署 Qbittorrent
echo "正在拉取 Qbittorrent 镜像..."
docker pull ysx88/qbittorrent:latest || { echo "错误: 无法拉取 Qbittorrent 镜像，请检查网络。"; exit 1; }
echo "正在部署 Qbittorrent 容器..."
docker run -d \
  --name=qbittorrent \
  --restart=always \
  -p $QBITTORRENT_WEBUI_PORT:8080 \
  -p $QBITTORRENT_PEER_PORT:6881 \
  -p $QBITTORRENT_PEER_PORT:6881/udp \
  -e PUID=$PUID \
  -e PGID=$PGID \
  -e TZ=$DEFAULT_TZ \
  -e WEBUI_PORT=8080 \
  -v $QBITTORRENT_CONFIG_DIR:/config \
  -v $MEDIA_DOWNLOADS_PATH:/downloads \
  --network host \
  ysx88/qbittorrent:latest

# 4. 部署 Emby
echo "正在拉取 Emby 镜像..."
docker pull ysx88/embyserver:latest || { echo "错误: 无法拉取 Emby 镜像，请检查网络。"; exit 1; }
echo "正在部署 Emby 容器..."
docker run -d \
  --name=Emby \
  --restart=always \
  -p $EMBY_PORT:8096 \
  -p $EMBY_HTTPS_PORT:8920 \
  -e UID=$PUID \
  -e GID=$PGID \
  -e TZ=$DEFAULT_TZ \
  -e PROXY_HOST=$DEFAULT_PROXY \
  -v $EMBY_CONFIG_DIR:/config \
  -v $EMBY_CONFIG_DIR/cache:/cache \
  -v $MEDIA_MOVIES_PATH:/media/$MEDIA_MOVIES_DIR \
  -v $MEDIA_TVSHOWS_PATH:/media/$MEDIA_TVSHOWS_DIR \
  -v $MEDIA_DOWNLOADS_PATH:/media/$MEDIA_DOWNLOADS_DIR \
  --device /dev/dri:/dev/dri \
  ysx88/embyserver:latest

# 5. 部署 MoviePilot
echo "正在拉取 MoviePilot 镜像..."
docker pull ysx88/moviepilot:latest || { echo "错误: 无法拉取 MoviePilot 镜像，请检查网络。"; exit 1; }
echo "正在部署 MoviePilot 容器..."
docker run -d \
  --name=moviePilot \
  --hostname=moviepilot \
  --restart=always \
  -p $MOVIEPILOT_PORT:3000 \
  -e NGINX_PORT=3000 \
  -e PORT=3001 \
  -e UID=$PUID \
  -e GID=$PGID \
  -e TZ=$DEFAULT_TZ \
  -e SUPERUSER=$DEFAULT_SUPERUSER \
  -e API_TOKEN=$DEFAULT_API_TOKEN \
  -e AUTH_SITE=iyuu \
  -e IYUU_SIGN=IYUU40388T1caf2124045bd5512f35b3718e3c51bee8bf12da \
  -e PROXY_HOST=$DEFAULT_PROXY \
  -e MESSAGER=wechat \
  -e WECHAT_CORPID=ww9e3020b322efefe8 \
  -e WECHAT_APP_SECRET=T4W-3c-fb9_9h9HSiDBKgbCg33MJo_BKhEc2SUl87SA \
  -e WECHAT_APP_ID=1000006 \
  -e WECHAT_TOKEN=qq1JQKjbfAqvD7a \
  -e WECHAT_ENCODING_AESKEY=tKIK2USROI3W5mzbQZf48r1s75TJGQsw1QY9KowzRCt \
  -e WECHAT_PROXY=http://198.12.121.200:9080 \
  -v $MEDIA_MOVIES_PATH:/media/$MEDIA_MOVIES_DIR \
  -v $MEDIA_TVSHOWS_PATH:/media/$MEDIA_TVSHOWS_DIR \
  -v $MEDIA_DOWNLOADS_PATH:/media/$MEDIA_DOWNLOADS_DIR \
  -v $MOVIEPILOT_CONFIG_DIR:/config \
  -v $MOVIEPILOT_CONFIG_DIR/core:/moviepilot/.cache/ms-playwright \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /etc/hosts:/etc/hosts \
  ysx88/moviepilot:latest

# 6. 部署 CookieCloud
echo "正在拉取 CookieCloud 镜像..."
docker pull ysx88/cookiecloud:latest || { echo "错误: 无法拉取 CookieCloud 镜像，请检查网络。"; exit 1; }
echo "正在部署 CookieCloud 容器..."
docker run -d \
  --name=cookiecloud \
  --restart=always \
  -p $COOKIECLOUD_PORT:8088 \
  -e API_ROOT=/skywrt \
  -v $COOKIECLOUD_CONFIG_DIR/data:/data/api/data \
  ysx88/cookiecloud:latest

# 7. 部署 Watchtower
echo "正在拉取 Watchtower 镜像..."
docker pull containrrr/watchtower || { echo "错误: 无法拉取 Watchtower 镜像，请检查网络。"; exit 1; }
echo "正在部署 Watchtower 容器..."
docker run -d \
  --name=watchtower \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e TZ=$DEFAULT_TZ \
  containrrr/watchtower -i 3600 --cleanup

if [ $? -eq 0 ]; then
    echo -e "\n========================================="
    echo "所有服务部署成功！"
    echo "你可以通过以下地址访问它们："
    echo "Portainer:    http://你的NAS_IP:$PORTTAINER_PORT"
    echo "Filebrowser:  http://你的NAS_IP:$FILEBROWSER_PORT"
    echo "Qbittorrent:  http://你的NAS_IP:$QBITTORRENT_WEBUI_PORT"
    echo "Emby:        http://你的NAS_IP:$EMBY_PORT"
    echo "MoviePilot:  http://你的NAS_IP:$MOVIEPILOT_PORT"
    echo "CookieCloud: http://你的NAS_IP:$COOKIECLOUD_PORT"
    echo "========================================="
    echo -e "\n媒体库目录结构："
    echo "下载目录: $MEDIA_DOWNLOADS_PATH"
    echo "├── 华语电影"
    echo "├── 外语电影"
    echo "├── 国产剧"
    echo "├── 欧美剧"
    echo "└── 日韩剧"
    echo ""
    echo "电影目录: $MEDIA_MOVIES_PATH"
    echo "├── 华语电影"
    echo "└── 外语电影"
    echo ""
    echo "电视剧目录: $MEDIA_TVSHOWS_PATH"
    echo "├── 国产剧"
    echo "├── 欧美剧"
    echo "└── 日韩剧"
    echo "========================================="
    echo "注意：请在各服务的后台设置中配置正确的媒体库路径"
    echo "========================================="
else
    echo -e "\n错误：Docker 容器启动失败。"
    echo "请检查以上步骤或使用 'docker logs <容器名称>' 获取更多信息。"
fi
