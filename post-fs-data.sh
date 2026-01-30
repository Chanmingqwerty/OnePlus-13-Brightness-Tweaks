#!/system/bin/sh

MODPATH="${0%/*}"
# 系统基础路径
BASE_DIR="/my_product/vendor/etc"

# ==========================================
# 挂载函数 (定义在最前方便调用)
# ==========================================
mount_file() {
    local mod_file="$1"
    local target_file="$2"
    
    if [ -s "$mod_file" ] && [ -f "$target_file" ]; then
        mount -o bind "$mod_file" "$target_file"
        chmod 0644 "$mod_file"
        chcon u:object_r:system_file:s0 "$mod_file" 2>/dev/null
    fi
}

# ==========================================
# 1. Feature Config (清空 HdrGeneric) - [保留]
# ==========================================
FILE_FEATURE="multimedia_display_feature_config.xml"
TARGET_FEATURE="$BASE_DIR/$FILE_FEATURE"
MOD_FEATURE="$MODPATH/$FILE_FEATURE"

if [ -f "$TARGET_FEATURE" ]; then
    awk '
      /<feature name="HdrGeneric"/ { in_block = 1 }
      in_block && /<\/feature>/ { in_block = 0 }
      in_block && /<supportApp>/ { next }
      { print }
    ' "$TARGET_FEATURE" > "$MOD_FEATURE"
    mount_file "$MOD_FEATURE" "$TARGET_FEATURE"
fi

# ==========================================
# 2. UIR Config (修改限值) - [保留]
# ==========================================
FILE_UIR="multimedia_display_uir_config.xml"
TARGET_UIR="$BASE_DIR/$FILE_UIR"
MOD_UIR="$MODPATH/$FILE_UIR"

if [ -f "$TARGET_UIR" ]; then
    cp "$TARGET_UIR" "$MOD_UIR"
    sed -i 's|<brightness_nit_limit>.*</brightness_nit_limit>|<brightness_nit_limit>1600</brightness_nit_limit>|g' "$MOD_UIR"
    sed -i 's|<temperature_limit>.*</temperature_limit>|<temperature_limit>100000</temperature_limit>|g' "$MOD_UIR"
    sed -i 's|<max_ratio>.*</max_ratio>|<max_ratio>999</max_ratio>|g' "$MOD_UIR"
    mount_file "$MOD_UIR" "$TARGET_UIR"
fi

# ==========================================
# 3. Brightness Config (P系列多机型适配) - [UPDATED]
# ==========================================
# 逻辑：遍历所有符合 display_brightness_config_P_?.xml 的文件
# 动作：无论原值如何，强制 max -> 4674, min -> 1

# 使用 find 或者直接 shell 通配符遍历
for target_file in "$BASE_DIR"/display_brightness_config_P_?.xml; do
    # 检查文件是否存在（避免通配符未匹配时出错）
    if [ -f "$target_file" ]; then
        filename=$(basename "$target_file")
        mod_file="$MODPATH/$filename"
        
        # 复制原文件
        cp "$target_file" "$mod_file"
        
        # 正则替换：匹配 max="..." 和 min="..." 中的任意内容并替换
        # 使用 -E 启用扩展正则，[^"]* 代表匹配双引号内的任意字符
        sed -i -E 's/max="[^"]*"/max="4674"/g' "$mod_file"
        sed -i -E 's/min="[^"]*"/min="1"/g' "$mod_file"
        
        # 挂载
        mount_file "$mod_file" "$target_file"
    fi
done

# ==========================================
# 4. Apollo List (多机型适配) - [UPDATED]
# ==========================================
# 逻辑：遍历 display_apollo_list_.*_P_?_.*_dsc_cmd_mode_panel.xml
# 动作：无论原值如何，强制 range -> 4674, region_min -> 1

for target_file in "$BASE_DIR"/display_apollo_list_*_P_?_*_dsc_cmd_mode_panel.xml; do
    if [ -f "$target_file" ]; then
        filename=$(basename "$target_file")
        mod_file="$MODPATH/$filename"
        
        cp "$target_file" "$mod_file"
        
        # 正则替换 range 和 region_min
        sed -i -E 's/range="[^"]*"/range="4674"/g' "$mod_file"
        sed -i -E 's/region_min="[^"]*"/region_min="1"/g' "$mod_file"
        
        mount_file "$mod_file" "$target_file"
    fi
done

# ==========================================
# 5. Brightness App List (全局限制 + FOSS Ratio) - [保留]
# ==========================================
FILE_APP_LIST="display_brightness_app_list.xml"
TARGET_APP_LIST="$BASE_DIR/$FILE_APP_LIST"
MOD_APP_LIST="$MODPATH/$FILE_APP_LIST"

if [ -f "$TARGET_APP_LIST" ]; then
    awk '
        # 任务1: 修改全局亮度限制 1200 -> 1600
        /<global_brightness_limit/ {
            sub(/nit="[^"]*"/, "nit=\"1600\"")
        }

        # 任务2: 修改 <foss> -> <type> 下的 <ratio>
        /<foss/ { in_foss = 1 }
        /<\/foss>/ { in_foss = 0 }
        in_foss && /<type/ { in_type = 1 }
        in_foss && /<\/type>/ { in_type = 0 }
        in_foss && in_type && /<ratio>/ {
            gsub(/<ratio>[^<]+<\/ratio>/, "<ratio>1.05</ratio>")
        }

        { print }
    ' "$TARGET_APP_LIST" > "$MOD_APP_LIST"
    mount_file "$MOD_APP_LIST" "$TARGET_APP_LIST"
fi

# ==========================================
# 6. 挂载用户自带的特定文件 - [保留]
# ==========================================
CUSTOM_BRIGHTNESS_SRC="$MODPATH/my_product/vendor/etc/multimedia_display_brightness_config.xml"
CUSTOM_BRIGHTNESS_TGT="/my_product/vendor/etc/multimedia_display_brightness_config.xml"

if [ -f "$CUSTOM_BRIGHTNESS_SRC" ]; then
    mount_file "$CUSTOM_BRIGHTNESS_SRC" "$CUSTOM_BRIGHTNESS_TGT"
fi

exit 0