#!/bin/bash
# 自动修改 index.html 中的静态资源版本号为当前时间戳
TIMESTAMP=$(date +%s)
sed -i -E "s/(href=\"styles\.css\?v=)[0-9]+(\")/\1${TIMESTAMP}\2/g" index.html
sed -i -E "s/(src=\"app\.js\?v=)[0-9]+(\")/\1${TIMESTAMP}\2/g" index.html
echo "版本号已更新为: ${TIMESTAMP}"
