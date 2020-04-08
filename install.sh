######################
# 配置开关
######################

# 调试模式
DEBUG_FLAG=false

# 跳过修改system 启用=true,关闭=false
SKIPMOUNT=false

# system.prop 启用=true,关闭=false
PROPFILE=false

# post-fs-data 启用=true,关闭=false
POSTFSDATA=false

# service.sh 启用=true,关闭=false
LATESTARTSERVICE=false

#####################
# 替换列表
#####################

# 列出要在系统中直接替换的所有目录
# 查看官方文档以获取有关您需要的更多信息

# 按以下格式构建列表
# 这是一个例子
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# 在这里构建自定义列表
REPLACE="
"

######################
#
# 函数调用
#
# 安装框架将调用以下函数。
# 您无法修改update-binary，这是您可以自定义的唯一方法
# 安装时通过实现这些功能。
#
# 在运行回调时，安装框架将确保Magisk
# 内部busybox的路径是*PREPENDED*到PATH,因此,所有常用命令应存在。
# 此外,它还将确保正确安装/data, /system和/vendor.
#
######################
######################
#
# 安装框架将导出一些变量和函数。
# 您应该使用这些变量和函数进行安装。
# 
# !不要使用任何Magisk内部路径，因为它们不是公共API。
# !不保证非公共API可以保持版本之间的兼容性。
#
# 可用变量:
#
# MAGISK_VER （字符串）：当前安装的Magisk的版本字符串（例如v20.0 ）
# MAGISK_VER_CODE （int）：当前安装的Magisk的版本代码（例如20000 ）
# BOOTMODE （bool）：如果在Magisk Manager中安装了模块，则为true
# MODPATH （路径）：应在其中安装模块文件的路径
# TMPDIR （路径）：可以临时存储文件的地方
# ZIPFILE （路径）：模块的安装zip
# ARCH （字符串）：设备的C​​PU体系结构。 值是arm ， arm64 ， x86或x64
# IS64BIT （bool）：如果$ARCH是arm64或x64 ， arm64 true
# API （int）：设备的API级别（Android版本）（例如，Android 5.0为21 ）
#
# 可用功能:
#
# ui_print <msg>
#     打印 <msg> 到安装界面
#     避免使用 'echo' 因为它不会显示在自定义安装界面
#
# abort <msg>
#     打印错误消息 <msg> 到安装界面和终止安装
#     避免使用 'exit' 因为它会跳过终止清理步骤
#
# set_perm <target> <owner> <group> <permission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     this function is a shorthand for the following commands
#       chown owner.group target
#       chmod permission target
#       chcon context target
#
# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     for all files in <directory>, it will call:
#       set_perm file owner group filepermission context
#     for all directories in <directory> (including itself), it will call:
#       set_perm dir owner group dirpermission context
#
#####################
# 如果需要启动脚本，请不要使用通用启动脚本 (post-fs-data.d/service.d)
# 只使用模块的脚本，因为它尊重模块状态 (remove/disable) and is
# 保证在未来的Magisk版本中保持相同的行为.
# 通过设置上面config部分中的标志启用引导脚本.
#####################

# 设置安装模块时要显示的内容

var_device="`grep_prop ro.product.system.device`"
var_version="`grep_prop ro.system.build.version.release`"
var_selinux="`getenforce`"

print_modname() {
  ui_print "*******************************"
  ui_print "    模板作者: 笨蛋海绵     "
  ui_print "    联系作者: 1037886804  "
  ui_print "    手机型号: $var_device"
  ui_print "    系统版本: Android $var_version"
  ui_print "    系统架构: $ARCH"
  ui_print "    SeLinux: $var_selinux"
  ui_print "*******************************"
}

keytest() {
  ui_print "- 音量键测试 -"
  ui_print "   请按下 [音量+] 键："
  ui_print "   无反应或传统模式无法正确安装时，请触摸一下屏幕后继续"
  (/system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $TMPDIR/events) || return 1
  return 0
}

chooseport() {
  #note from chainfire @xda-developers: getevent behaves weird when piped, and busybox grep likes that even less than toolbox/toybox grep
  while (true); do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $TMPDIR/events
    if (`cat $TMPDIR/events 2>/dev/null | /system/bin/grep VOLUME >/dev/null`); then
      break
    fi
  done
  if (`cat $TMPDIR/events 2>/dev/null | /system/bin/grep VOLUMEUP >/dev/null`); then
    return 0
  else
    return 1
  fi
}

chooseportold() {
  # Calling it first time detects previous input. Calling it second time will do what we want
  $KEYCHECK
  $KEYCHECK
  SEL=$?
  $DEBUG_FLAG && ui_print "  DEBUG: chooseportold: $1,$SEL"
  if [ "$1" == "UP" ]; then
    UP=$SEL
  elif [ "$1" == "DOWN" ]; then
    DOWN=$SEL
  elif [ $SEL -eq $UP ]; then
    return 0
  elif [ $SEL -eq $DOWN ]; then
    return 1
  else
    abort "   未检测到音量键!"
  fi
}

on_install() {
  unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2

  # Keycheck binary by someone755 @Github, idea for code below by Zappo @xda-developers
  KEYCHECK=$TMPDIR/keycheck
  chmod 755 $KEYCHECK
  # 测试音量键
  if keytest; then
    VOLKEY_FUNC=chooseport
    ui_print "*******************************"
  else
    VOLKEY_FUNC=chooseportold
    ui_print "*******************************"
    ui_print "- 检测到遗留设备！使用旧的 keycheck 方案 -"
    ui_print "- 进行音量键录入 -"
    ui_print "   录入：请按下 [音量+] 键："
    $VOLKEY_FUNC "UP"
    ui_print "   已录入 [音量+] 键。"
    ui_print "   录入：请按下 [音量-] 键："
    $VOLKEY_FUNC "DOWN"
    ui_print "   已录入 [音量-] 键。"
  ui_print "*******************************"
  fi
  
  
  
  ui_print " "
  ui_print "   请选择是否启用自动更新模块服务"
  ui_print "   Vol+上音量键 = 启用自动更新, Vol-下音量键 = 禁用自动更新"
  if $VOLKEY_FUNC; then
    ui_print " "
    ui_print "   已启用自动更新模块服务"
    cp -rf $TMPDIR/update_service.sh /data/adb/service.d/$MODID
    chmod 777 /data/adb/service.d/$MODID
  else
    ui_print " "
    ui_print "   已禁用自动更新模块服务"
    rm -f /data/adb/service.d/$MODID
  fi
  
  ui_print " "
  ui_print "************************************"
  ui_print "     By 笨蛋海绵(QQ:1037886804)"
  ui_print "************************************"
  
}

# 只有一些特殊文件需要特定权限
# 安装完成后，此功能将被调用
# 对于大多数情况，默认权限应该已经足够

set_permissions() {
  # 以下是默认规则,请勿删除
  set_perm_recursive $MODPATH 0 0 0755 0644


  # 以下是一些例子:
  # set_perm_recursive  $MODPATH/system/lib 0 0 0755 0644
  # set_perm  $MODPATH/system/bin/app_process32 0 2000 0755 u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat 0 2000 0755 u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so 0 0 0644
}

# 您可以添加更多功能来协助您的自定义脚本代码