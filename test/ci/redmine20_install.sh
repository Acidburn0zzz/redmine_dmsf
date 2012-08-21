#/bin/bash
#
# This script is almost entirely built on the build script from redmine_backlogs
# Please see: https://github.com/backlogs/redmine_backlogs
#

if [[ -e "$HOME/.dmsf.rc" ]]; then
  source "$HOME/.dmsf.rc"
fi

if [[ ! "$WORKSPACE" = /* ]] ||
   [[ ! "$PATH_TO_REDMINE" = /* ]] ||
   [[ ! "$PATH_TO_DMSF" = /* ]];
then
  echo "You should set"\
       " WORKSPACE, PATH_TO_REDMINE, PATH_TO_DMSF"\
       " environment variables"
  echo "You set:"\
       "$WORKSPACE"\
       "$PATH_TO_REDMINE"\
       "$PATH_TO_DMSF"
  exit 1;
fi

export PATH_TO_PLUGINS=./plugins # for redmine 2.0
export GENERATE_SECRET=generate_secret_token
export MIGRATE_PLUGINS=redmine:plugins:migrate
export REDMINE_GIT_REPO=git://github.com/edavis10/redmine.git
export REDMINE_GIT_TAG=2.0.3
export BUNDLE_GEMFILE=$PATH_TO_REDMINE/Gemfile

clone_redmine()
{
  set -e # exit if clone fails
  rm -rf $PATH_TO_REDMINE
  git clone -b master --depth=100 --quiet $REDMINE_GIT_REPO $PATH_TO_REDMINE
  cd $PATH_TO_REDMINE
  git checkout $REDMINE_GIT_TAG
}

run_tests()
{
  # exit if tests fail
  set -e

  cd $PATH_TO_REDMINE


  mkdir -p coverage
  ln -sf `pwd`/coverage $WORKSPACE

  #Run tests within application
  bundle exec rake redmine:plugins:test NAME=redmine_dmsf
}

uninstall()
{
  set -e # exit if migrate fails
  cd $PATH_TO_REDMINE
  # clean up database
  bundle exec rake $MIGRATE_PLUGINS NAME=redmine_dmsf VERSION=0 RAILS_ENV=test
  bundle exec rake $MIGRATE_PLUGINS NAME=redmine_dmsf VERSION=0 RAILS_ENV=development
}

run_install()
{
# exit if install fails
set -e

# cd to redmine folder
cd $PATH_TO_REDMINE
echo current directory is `pwd`

# create a link to the dmsf plugin
ln -sf $PATH_TO_DMSF $PATH_TO_PLUGINS/redmine_dmsf

#ignore redmine-master's test-unit dependency, we need 1.2.3
#sed -i -e 's=.*gem ["'\'']test-unit["'\''].*==g' ${PATH_TO_REDMINE}/Gemfile
# install gems
mkdir -p vendor/bundle
bundle install --path vendor/bundle

# copy database.yml
cp $WORKSPACE/database.yml config/

# run redmine database migrations
bundle exec rake db:migrate RAILS_ENV=test --trace
bundle exec rake db:migrate RAILS_ENV=development --trace

# install redmine database
bundle exec rake redmine:load_default_data REDMINE_LANG=en RAILS_ENV=development

# generate session store/secret token
bundle exec rake $GENERATE_SECRET

# enable development features
touch dmsf.dev

# run dmsf database migrations
bundle exec rake $MIGRATE_PLUGINS RAILS_ENV=test
bundle exec rake $MIGRATE_PLUGINS RAILS_ENV=development
}

while getopts :irtu opt
do case "$opt" in
  r)  clone_redmine; exit 0;;
  i)  run_install;  exit 0;;
  t)  run_tests;  exit 0;;
  u)  uninstall;  exit 0;;
  [?]) echo "i: install; r: clone redmine; t: run tests; u: uninstall";;
  esac
done