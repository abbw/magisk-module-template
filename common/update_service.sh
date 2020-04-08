#!/system/bin/sh

until [ $(getprop sys.boot_completed) -eq 1 ]
do 
    sleep 2
done
sleep 30

mod_id=${0##*/}
update_url="https://gitee.com/abbw/blog/raw/master/$mod_id"
path="/storage/emulated/0/$mod_id.log"
mod_file="/data/adb/modules/$mod_id"
MOD_FILES="/storage/emulated/0/Download/"$mod_id"_update"
MODPATH="/data/adb/modules_update/$mod_id"

if [ ! -d "$mod_file" ];then
  rm -rf $0
else
  var=`sed -n 8p $mod_file/module.prop`
  mod_version=${var#*=}
  iptables -F
  [ ! -f $path ]
  until [ $? -eq 1 ]
  do
    curl -L $update_url -o $path
    
    [ ! -f $path ]
  done
  grep "html" $path > /dev/null
  
  if [ $? -eq 1 ];then
    sed -i 's/\[.*\]//g' $path
    var_name=`sed -n 1p $path`
    var_force=`sed -n 2p $path`
    var_url=`sed -n 3p $path`
    var_version=`sed -n 4p $path`
    
    echo $path
    rm -rf $path
   
    if [ "$var_version" == "" ];then
      echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 未找到更新地址，跳过更新"  >> "/storage/emulated/0/abbw_update.log"
      exit
    fi
    
    echo $mod_version | grep -q $var_version
    
    if [ $? -eq 0 ];then
      echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 版本一致，跳过更新"  >> "/storage/emulated/0/abbw_update.log"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 当前版本:$mod_version 最新版本:$var_version" >> "/storage/emulated/0/abbw_update.log"
      echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 检测更新包是否已下载" >> "/storage/emulated/0/abbw_update.log"
      unzip -l $MOD_FILES/update.zip
      if [ $? -eq 0 ];then
        echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 更新包已下载，请自行刷入" >> "/storage/emulated/0/abbw_update.log"
        sed -i 's/description.*/description=发现新版本'$var_version',非强制性更新,已下载更新包至Download\/'$mod_id'_update下,有需要请自行刷入/g' $mod_file/module.prop
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 未发现更新包，开始下载更新包" >> "/storage/emulated/0/abbw_update.log"
        sed -i 's/description.*/description=模块有新版本'$var_version'发布,当前正在后台龟速下载中,下拉刷新模块列表更新进度信息/g' $mod_file/module.prop
        mkdir -p $MOD_FILES
        cd $MOD_FILES
        i=1
        curl -L $var_url -o ./update.zip
        unzip -l ./update.zip
        until [ $? -eq 0 ]
        do
          i=$((i + 1))
          sed -i 's/description.*/description=发现新版本'$var_version',当前正在进行第'$i'次下载(若干次本条状态还没有更新,那可能是作者网址搞错了,请联系作者修改网址或关闭更新)下拉刷新模块列表更新进度信息/g' $mod_file/module.prop
          curl -L $var_url -o ./update.zip
          unzip -l ./update.zip
        done
        echo $var_force | grep -q off
        if [ $? -eq 0 ];then
          echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 非强制更新，已下载更新包，有需要请自行刷入" >> "/storage/emulated/0/abbw_update.log"
          sed -i 's/description.*/description=发现新版本'$var_version',非强制性更新,已下载更新包至Download\/'$mod_id'_update下,有需要请自行刷入/g' $mod_file/module.prop
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') 模块ID:$mod_id 强制更新，更新后请重启" >> "/storage/emulated/0/abbw_update.log"
          sed -i 's/description.*/description=发现新版本'$var_version',强制性更新,当前已下载完成,正在后台安装,下拉刷新模块列表更新进度信息/g' $mod_file/module.prop
          unzip -o ./update.zip -d ./
          . $MOD_FILES/common/update.sh
          rm -rf $MOD_FILES
          sed -i 's/description.*/description=发现新版本'$var_version',强制性更新,当前状态已经完成,请重启手机/g' $mod_file/module.prop
        fi
      fi
    fi
  fi
fi