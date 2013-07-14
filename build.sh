#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    (repo forall -c "git reset --hard") >/dev/null
    rm -f .repo/local_manifests/dyn-*.xml
    rm -f .repo/local_manifests/roomservice.xml
    echo $1
    exit 1
  fi
}

if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

if [ -z "$WORKSPACE" ]
then
  echo WORKSPACE not specified
  exit 1
fi

if [ -z "$CLEAN" ]
then
  echo CLEAN not specified
  exit 1
fi

if [ -z "$REPO_BRANCH" ]
then
  if [[ "$ROM" =~ "liquid" || $ROM =~ "LiquidSmooth" ]]; then
   export REPO_BRANCH=jb2
   export FOLDERPREFIX=liquid
  elif [[ "$ROM" =~ "pa" || $ROM =~ "ParanoidAndroid" ]]; then
   export REPO_BRANCH=jellybean-legacy
   export FOLDERPREFIX=pa
  elif [[ "$ROM" =~ "sb" || $ROM =~ "SlimBean" ]]; then
   export REPO_BRANCH=jb4.2
   export FOLDERPREFIX=sb
  elif [[ "$ROM" =~ "cm" || $ROM =~ "CyanogenMod" ]]; then
   export REPO_BRANCH=cm-10.1
   export FOLDERPREFIX=cm
  else
   export REPO_BRANCH=cm-10.1
   export FOLDERPREFIX=cm
fi
else
  if [[ "$REPO_BRANCH" =~ "jellybean" || $REPO_BRANCH =~ "jellybean-legacy" ]]; then
   export FOLDERPREFIX=pa
  elif [[ "$REPO_BRANCH" =~ "cm-10" || $REPO_BRANCH =~ "cm-10.1" ]]; then
   export FOLDERPREFIX=cm
  else
   echo notification: upload not supported in combination with branch $REPO_BRANCH
  fi
fi

if [ -z "$LUNCH" ]
then
  echo LUNCH not specified
  exit 1
fi

if [ -z "$RELEASE_TYPE" ]
then
  echo RELEASE_TYPE not specified
  exit 1
fi

if [ -z "$SYNC_PROTO" ]
then
  SYNC_PROTO=git
fi

if [ -z "$UPLOAD" ]
then
  echo UPLOAD not specified
  exit 1
fi

# colorization fix in Jenkins
export CL_RED="\"\033[31m\""
export CL_GRN="\"\033[32m\""
export CL_YLW="\"\033[33m\""
export CL_BLU="\"\033[34m\""
export CL_MAG="\"\033[35m\""
export CL_CYN="\"\033[36m\""
export CL_RST="\"\033[0m\""

cd $WORKSPACE
rm -rf archive
mkdir -p archive
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER

export PATH=~/bin:$PATH

export USE_CCACHE=1
export CCACHE_NLEVELS=4
export BUILD_WITH_COLORS=0

platform=`uname -s`
if [ "$platform" = "Darwin" ]
then
  export BUILD_MAC_SDK_EXPERIMENTAL=1
fi

REPO=$(which repo)
if [ -z "$REPO" ]
then
  mkdir -p ~/bin
  curl https://dl-ssl.google.com/dl/googlesource/git-repo/repo > ~/bin/repo
  chmod a+x ~/bin/repo
fi

git config --global user.name $(whoami)@$NODE_NAME
git config --global user.email jenkins@cyanogenmod.com

if [[ "$ROM" =~ "pa" || $ROM =~ "ParanoidAndroid" ]]; then
   DEVICE=ace
   export ROMPROJECT=ParanoidAndroid
   export MANIFESTNAME=manifest
elif [[ "$ROM" =~ "liquid" || $ROM =~ "LiquidSmooth" ]]; then
   export ROMPROJECT=LiquidSmooth
   export MANIFESTNAME=android
elif [[ "$ROM" =~ "slim" || $ROM =~ "SlimBean" ]]; then
   export ROMPROJECT=SlimRoms
   export MANIFESTNAME=platform_manifest
elif [[ "$ROM" =~ "cm" || $ROM =~ "CyanogenMod" ]]; then
   export ROMPROJECT=CyanogenMod
   export MANIFESTNAME=android
else
   export ROMPROJECT=CyanogenMod
   export MANIFESTNAME=android
fi

if [[ "$LUNCH" =~ "cm_ace-userdebug" || $LUNCH =~ "pa_ace-userdebug" || $LUNCH =~ "liquid_ace-userdebug" || $LUNCH =~ "slim_ace-userdebug" ]]; then
   DEVICE=ace
   export GITHUBUSER=yanniks
elif [[ "$LUNCH" =~ "cm_mako-userdebug" || $LUNCH =~ "pa_mako-userdebug" ]]; then
   DEVICE=mako
   export GITHUBUSER=CyanogenMod
else
   JENKINS_BUILD_DIR=$REPO_BRANCH
   export GITHUBUSER=CyanogenMod
fi

if [[ "$REPO_BRANCH" =~ "cm-10.1" || $REPO_BRANCH =~ "cm-10" ]]; then 
   JENKINS_BUILD_DIR=jellybean
   export REPOLOCAL=cm-10.1
elif [[ "$REPO_BRANCH" =~ "jellybean" || $REPO_BRANCH =~ "jellybean-legacy" ]]; then
   JENKINS_BUILD_DIR=paranoidandroid
   export REPOLOCAL=jellybean-legacy
elif [[ "$REPO_BRANCH" =~ "jb2" || $REPO_BRANCH =~ "jb2" ]]; then
   JENKINS_BUILD_DIR=liquidsmooth
   export REPOLOCAL=jb2
elif [[ "$REPO_BRANCH" =~ "jb4.2" || $REPO_BRANCH =~ "jb4.2" ]]; then
   JENKINS_BUILD_DIR=slimbean
   export REPOLOCAL=jb4.2
else
   JENKINS_BUILD_DIR=$REPO_BRANCH
fi

export DEVICE=$DEVICE
rm -f $JENKINS_BUILD_DIR/out/target/product/$DEVICE/system/build.prop
export JENKINS_BUILD_DIR

mkdir -p $JENKINS_BUILD_DIR
cd $JENKINS_BUILD_DIR

# always force a fresh repo init since we can build off different branches
# and the "default" upstream branch can get stuck on whatever was init first.
if [ -z "$CORE_BRANCH" ]
then
  CORE_BRANCH=$REPO_BRANCH
fi

if [ ! -z "$RELEASE_MANIFEST" ]
then
  MANIFEST="-m $RELEASE_MANIFEST"
else
  RELEASE_MANIFEST=""
  MANIFEST=""
fi

rm -rf .repo/manifests*
rm -rf .repo/local_manifests
rm -f .repo/local_manifests/*.xml
repo init -u $SYNC_PROTO://github.com/$ROMPROJECT/$MANIFESTNAME.git -b $CORE_BRANCH $MANIFEST
if [[ "$LUNCH" =~ "cm_ace-userdebug" || $LUNCH =~ "cm_ace-eng" ]]; then 
	mkdir .repo/local_manifests
	curl -s -o .repo/local_manifests/ace_manifest.xml https://raw.github.com/yanniks/android/$REPOLOCAL/ace_manifest.xml
elif [[ "$LUNCH" =~ "pa_ace-userdebug" || $LUNCH =~ "pa_ace-eng" ]]; then
        mkdir .repo/local_manifests
        curl -s -o .repo/local_manifests/ace_manifest.xml https://raw.github.com/pa-ace/android/$REPOLOCAL/ace_manifest.xml
elif [[ "$LUNCH" =~ "slim_ace-userdebug" || $LUNCH =~ "slim_ace-eng" ]]; then
        mkdir .repo/local_manifests
        curl -s -o .repo/local_manifests/ace_manifest.xml https://raw.github.com/yanniks/android/$REPOLOCAL/ace_manifest.xml
elif [[ "$LUNCH" =~ "liquid_ace-userdebug" || $LUNCH =~ "liquid_ace-eng" ]]; then
        mkdir .repo/local_manifests
        curl -s -o .repo/local_manifests/ace_manifest.xml https://raw.github.com/yanniks/android/$REPOLOCAL/ace_manifest.xml
else
        echo not building for ace.
fi
check_result "repo init failed."

# make sure ccache is in PATH
if [[ "$REPO_BRANCH" =~ "jellybean" || $REPO_BRANCH =~ "cm-10" ]]
then
export PATH="$PATH:/opt/local/bin/:$PWD/prebuilts/misc/$(uname|awk '{print tolower($0)}')-x86/ccache"
export CCACHE_DIR=~/.jb_ccache
else
export PATH="$PATH:/opt/local/bin/:$PWD/prebuilt/$(uname|awk '{print tolower($0)}')-x86/ccache"
export CCACHE_DIR=~/.ics_ccache
fi

if [ -f ~/.jenkins_profile ]
then
  . ~/.jenkins_profile
fi

mkdir -p .repo/local_manifests
rm -f .repo/local_manifest.xml

if [ -f $WORKSPACE/build_env/bootstrap.sh ]
then
  bash $WORKSPACE/build_env/bootstrap.sh
fi

echo Core Manifest:
cat .repo/manifest.xml

## TEMPORARY: Some kernels are building _into_ the source tree and messing
## up posterior syncs due to changes
rm -rf kernel/*

if [[ "$SYNCREPO" =~ "false" || $SYNCREPO =~ "nein" ]]; then 
	echo Skipped sync.
else
	echo Syncing...
	repo sync -d -c > /dev/null
	check_result "repo sync failed."
	echo Sync complete.
fi
if [ "$RELEASE_TYPE" = "CM_RELEASE" ]
then
  if [ -f  $WORKSPACE/build_env/$REPO_BRANCH-release.xml ]
  then
    cp -f $WORKSPACE/build_env/$REPO_BRANCH-release.xml .repo/local_manifests/dyn-$REPO_BRANCH.xml
  fi
fi

echo Syncing...
repo sync -d -c > /dev/null
check_result "repo sync failed."
echo Sync complete.

if [ -f $WORKSPACE/hudson/$REPO_BRANCH-setup.sh ]
then
  $WORKSPACE/hudson/$REPO_BRANCH-setup.sh
else
  $WORKSPACE/hudson/cm-setup.sh
fi

if [ -f .last_branch ]
then
  LAST_BRANCH=$(cat .last_branch)
else
  echo "Last build branch is unknown, assume clean build"
  LAST_BRANCH=$REPO_BRANCH-$CORE_BRANCH$RELEASE_MANIFEST
fi

if [ "$LAST_BRANCH" != "$REPO_BRANCH-$CORE_BRANCH$RELEASE_MANIFEST" ]
then
  echo "Branch has changed since the last build happened here. Forcing cleanup."
  CLEAN="true"
fi

. build/envsetup.sh
# Workaround for failing translation checks in common hardware repositories
if [ ! -z "$GERRIT_XLATION_LINT" ]
then
    LUNCH=$(echo $LUNCH@$DEVICEVENDOR | sed -f $WORKSPACE/hudson/shared-repo.map)
fi

lunch $LUNCH
check_result "lunch failed."

# save manifest used for build (saving revisions as current HEAD)

# include only the auto-generated locals
TEMPSTASH=$(mktemp -d)
# save it
repo manifest -o $WORKSPACE/archive/manifest.xml -r

# restore all local manifests
mv $TEMPSTASH/* .repo/local_manifests/ 2>/dev/null
rmdir $TEMPSTASH

rm -f $OUT/*.zip*

UNAME=$(uname)

if [ ! -z "$BUILD_USER_ID" ]
then
  export RELEASE_TYPE=CM_EXPERIMENTAL
fi

if [ "$RELEASE_TYPE" = "CM_NIGHTLY" ]
then
  if [ "$REPO_BRANCH" = "gingerbread" ]
  then
    export CYANOGEN_NIGHTLY=true
  else
    export CM_NIGHTLY=true
  fi
elif [ "$RELEASE_TYPE" = "CM_EXPERIMENTAL" ]
then
  export CM_EXPERIMENTAL=true
elif [ "$RELEASE_TYPE" = "CM_RELEASE" ]
then
  # gingerbread needs this
  export CYANOGEN_RELEASE=true
  # ics needs this
  export CM_RELEASE=true
fi

if [ ! -z "$CM_EXTRAVERSION" ]
then
  export CM_EXPERIMENTAL=true
fi

if [ ! -z "$GERRIT_CHANGES" ]
then
  export CM_EXPERIMENTAL=true
  IS_HTTP=$(echo $GERRIT_CHANGES | grep http)
  if [ -z "$IS_HTTP" ]
  then
    python $WORKSPACE/hudson/repopick.py $GERRIT_CHANGES
    check_result "gerrit picks failed."
  else
    python $WORKSPACE/hudson/repopick.py $(curl $GERRIT_CHANGES)
    check_result "gerrit picks failed."
  fi
  if [ ! -z "$GERRIT_XLATION_LINT" ]
  then
    python $WORKSPACE/hudson/xlationlint.py $GERRIT_CHANGES
    check_result "basic XML lint failed."
  fi
fi

if [ ! "$(ccache -s|grep -E 'max cache size'|awk '{print $4}')" = "100.0" ]
then
  ccache -M 100G
fi

rm -f $WORKSPACE/changecount
WORKSPACE=$WORKSPACE LUNCH=$LUNCH bash $WORKSPACE/hudson/changes/buildlog.sh 2>&1
if [ -f $WORKSPACE/changecount ]
then
  CHANGE_COUNT=$(cat $WORKSPACE/changecount)
  rm -f $WORKSPACE/changecount
  if [ $CHANGE_COUNT -eq "0" ]
  then
    echo "Zero changes since last build, aborting"
    exit 0
  fi
fi

LAST_CLEAN=0
if [ -f .clean ]
then
  LAST_CLEAN=$(date -r .clean +%s)
fi
TIME_SINCE_LAST_CLEAN=$(expr $(date +%s) - $LAST_CLEAN)
# convert this to hours
TIME_SINCE_LAST_CLEAN=$(expr $TIME_SINCE_LAST_CLEAN / 60 / 60)
if [ $TIME_SINCE_LAST_CLEAN -gt "24" -o $CLEAN = "true" ]
then
  echo "Cleaning!"
  touch .clean
  make clobber
else
  echo "Skipping clean: $TIME_SINCE_LAST_CLEAN hours since last clean."
fi

echo "$REPO_BRANCH-$CORE_BRANCH$RELEASE_MANIFEST" > .last_branch

    if [ "$ROM" = "LiquidSmooth" ]
    then 
         time make
    else   
         time mka bacon
    fi

check_result "Build failed."

for f in $(ls $OUT/*.zip*)
do
  ln $f $WORKSPACE/archive/$(basename $f)
done
if [ -f $OUT/utilties/update.zip ]
then
  cp $OUT/utilties/update.zip $WORKSPACE/archive/recovery.zip
fi
if [ -f $OUT/recovery.img ]
then
  cp $OUT/recovery.img $WORKSPACE/archive
fi

# archive the build.prop as well
ZIP=$(ls $WORKSPACE/archive/*.zip)
unzip -p $ZIP system/build.prop > $WORKSPACE/archive/build.prop

# CORE: save manifest used for build (saving revisions as current HEAD)
rm -f .repo/local_manifests/dyn-$REPO_BRANCH.xml
rm -f .repo/local_manifests/roomservice.xml

# Stash away other possible manifests
TEMPSTASH=$(mktemp -d)
mv .repo/local_manifests $TEMPSTASH

repo manifest -o $WORKSPACE/archive/core.xml -r

mv $TEMPSTASH/local_manifests .repo
rmdir $TEMPSTASH

# chmod the files in case UMASK blocks permissions
chmod -R ugo+r $WORKSPACE/archive

CMCP=$(which cmcp)
if [ ! -z "$CMCP" -a ! -z "$CM_RELEASE" ]
then
  MODVERSION=$(cat $WORKSPACE/archive/build.prop | grep ro.modversion | cut -d = -f 2)
  if [ -z "$MODVERSION" ]
  then
    MODVERSION=$(cat $WORKSPACE/archive/build.prop | grep ro.cm.version | cut -d = -f 2)
  fi
  if [ -z "$MODVERSION" ]
  then
    echo "Unable to detect ro.modversion or ro.cm.version."
    exit 1
  fi
  echo Archiving release to S3.
  for f in $(ls $WORKSPACE/archive)
  do
    cmcp $WORKSPACE/archive/$f release/$MODVERSION/$f > /dev/null 2> /dev/null
    check_result "Failure archiving $f"
  done
fi
rm /media/yannik/android/jenkins/workspace/android/$JENKINS_BUILD_DIR/out/target/product/$DEVICE/*ota-eng*.zip
if [[ "$UPLOAD" =~ "true" || $UPLOAD =~ "ja" ]]; then 
	    if [ "$APPLYUPDATE" = "true" ]
	    then
                  adb shell rm /sdcard/Download/rom-update.zip
	          adb push /media/yannik/android/jenkins/workspace/android/$JENKINS_BUILD_DIR/out/target/product/$DEVICE/*.zip /sdcard/Download/rom-update.zip
		  adb shell su -c "mkdir -p /cache/recovery"
		  adb shell su -c "echo 'boot-recovery' > /cache/recovery/command"
		  adb shell su -c "echo '--update_package=/sdcard/Download/rom-update.zip' >> /cache/recovery/command"
		  adb reboot recovery
	    else
			echo skipped test installation!
	    fi
	cd /media/yannik/android/jenkins/workspace/android/$JENKINS_BUILD_DIR/out/target/product/$DEVICE/
	mv /media/yannik/android/jenkins/workspace/android/$JENKINS_BUILD_DIR/out/target/product/$DEVICE/*zip* $UPLOADPATH/$FOLDERPREFIX-$DEVICE-buildbot
            if [ "$RELEASE_TYPE" = "CM_RELEASE" ]
            then 
                  /home/yannik/cm-changes.sh
            else   
                  echo not a release build!   
            fi
elif [[ "$UPLOAD" =~ "testcompile" || $UPLOAD =~ "sofortloeschen" ]]; then
        rm $OUT/*.zip*
else
            if [ "$APPLYUPDATE" = "true" ]
            then
                  adb shell rm /sdcard/Download/rom-update.zip
                  adb push /media/yannik/android/jenkins/workspace/android/$JENKINS_BUILD_DIR/out/target/product/$DEVICE/*.zip /sdcard/Download/rom-update.zip
                  adb shell su -c "mkdir -p /cache/recovery"
                  adb shell su -c "echo 'boot-recovery' > /cache/recovery/command"
                  adb shell su -c "echo '--update_package=/sdcard/Download/rom-update.zip' >> /cache/recovery/command"
                  adb reboot recovery
            else
                        echo skipped test installation!
            fi
   echo not uploading
fi

            if [ "$DELETEOUT" = "true" ]
            then
                  echo deleting build directory...
                  rm -rf /media/yannik/android/jenkins/workspace/android/$JENKINS_BUILD_DIR/out
                  echo done!
            else
                        echo not deleting build directory.
            fi
