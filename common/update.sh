#!/system/bin/sh
#########
#模块更新脚本#
########

#写入更新命令
mkdir -p $mod_file/update
mkdir -p $MODPATH

#更新模块module.prop配置
cp -rf $MOD_FILES/module.prop $MODPATH/module.prop

#是否需要开启service等脚本[true/false]
service=false
post_fs_data=false
system_prop=false

##########
##########
echo $service | grep -q true
if [ $? -eq 0 ];then
  cp -rf $MOD_FILES/common/service.sh $MODPATH
fi
echo $post_fs_data | grep -q true
if [ $? -eq 0 ];then
  cp -rf $MOD_FILES/common/post-fs-data.sh $MODPATH
fi
echo $system_prop | grep -q true
if [ $? -eq 0 ];then
  cp -rf $MOD_FILES/common/system_prop $MODPATH
fi

#强制更新模块内容,需手动编写
cp -rf $MOD_FILES/install.sh $MODPATH/install.sh

