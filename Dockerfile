﻿# 第一阶段，拉取 node 基础镜像并安装依赖，执行构建
FROM node:12-alpine as builder
MAINTAINER Rex <talebook@foxmail.com>

LABEL Maintainer="Rex <talebook@foxmail.com>"
LABEL Thanks="oldiy <oldiy2018@gmail.com>"

WORKDIR /tmp/
COPY . /tmp/
RUN cd /tmp/app && \
        npm install . && \
        npm run build && \
        rm -rf node_modules


# 第二阶段，构建环境
FROM debian:9

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install tzdata && \
    apt-get install python-pip unzip supervisor sqlite3 git nginx python-setuptools curl -y --no-install-recommends && \
    apt-get install calibre=2.75.1+dfsg-1 -y

RUN pip install wheel
RUN pip install \
        Baidubaike==2.0.1 \
        jinja2==2.10 \
        social-auth-app-tornado==1.0.0 \
        social-auth-storage-sqlalchemy==1.1.0 \
        tornado==5.1.1 \
        bs4

RUN mkdir -p /data/log/nginx/ && \
    mkdir -p /data/books/library  && \
    mkdir -p /data/books/extract  && \
    mkdir -p /data/books/upload  && \
    mkdir -p /data/books/convert  && \
    mkdir -p /data/books/progress  && \
    mkdir -p /data/books/settings && \
    mkdir -p /var/www/calibre-webserver/ && \
    chmod a+w -R /data/log /data/books /var/www

COPY . /var/www/calibre-webserver/
COPY conf/nginx/calibre-webserver.conf.template /etc/nginx/conf.d/
COPY conf/supervisor/calibre-webserver.conf /etc/supervisor/conf.d/
COPY --from=builder /tmp/app/dist/ /var/www/calibre-webserver/app/dist/

RUN rm -f /etc/nginx/sites-enabled/default /var/www/html -rf && \
    cd /var/www/calibre-webserver/ && \
    cp app/dist/index.html webserver/templates/index.html && \
    touch /data/books/settings/auto.py && \
    chmod a+w /data/books/settings/auto.py && \
    chmod a+w app/dist/index.html && \
    calibredb add --library-path=/data/books/library/ -r docker/book/ && \
    python server.py --syncdb  && \
    rm -f webserver/*.pyc && \
    mkdir -p /prebuilt/ && \
    mv /data/* /prebuilt/ && \
    chmod +x /var/www/calibre-webserver/docker/start.sh

ENV NGINX_CLIENT_MAX_BODY_SIZE="20m"

EXPOSE 80

VOLUME ["/data"]

CMD ["/var/www/calibre-webserver/docker/start.sh"]

