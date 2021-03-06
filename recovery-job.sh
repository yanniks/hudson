if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

cd $WORKSPACE
mkdir -p ../android-recovery
cd ../android-recovery
export WORKSPACE=$PWD

if [ ! -d hudson ]
then
  git clone git://github.com/yanniks/hudson.git
fi

cd hudson
## Get rid of possible local changes
git reset --hard
git pull -s resolve

exec ./build-recovery.sh
