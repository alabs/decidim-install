#!/usr/bin/env bash
#
# Decidim installation script on Ubuntu 16.04 LTS and macos sierra 10.2
#
# This is a BETA and as such you should be aware that this could break your environment (if you have any)
# This will install rbenv, postgresql, nodejs and install decidim on this directory
# It'll take 15 minutes depending on your network connection
#

set -e
set -x

DB_USER=decidim_app
DB_PASS=$( openssl rand -base64 32 )
DECIDIM_DIR=decidim_application
RUBY_VERSION=2.3.1

function ascii_banner {
  echo "************************************************************************************************"
  echo "      █████████▓▌▄,               ╦╦⌐                  ]╫Ñ      .╦╦  j╫Ñ"
  echo "      ████████▀█████▌             ╫╫∩                           .╫╫     "
  echo "      ███████▌╫╫██████p       ╔NN╦╫╫∩  ,╦NN╦≈   ╔╦NN╦  j╫Ñ  .╦NN╦╫╫  jNN  jNu╦NN╦╔╦DN≈"
  echo "      █████▓╫╫╫╫╫▒▓████      j╫Ñ  ╫╫∩ :╫Ñ  ╫╫⌐ 1╫H ]╫H j╫Ñ  ╫╫H :╫╫  j╫Ñ  ]╫Ñ  ╫╫H :╫╫"
  echo "      ████▒╫╫╫╫╫╫╫▒▓███      ]╫N  ╫╫∩ j╫Ñ≈≈╫╫⌐ ╫╫H     j╫Ñ  ╫╫░ :╫╫  j╫Ñ  ]╫Ñ  ╫╫∩ :╫╫"
  echo "      ███████╫╫╫▒█████▌      ]╫N  ╫╫∩ j╫Ñ''''  ╫╫H     j╫Ñ  ╫╫░ :╫╫  j╫Ñ  ]╫Ñ  ╫╫∩ :╫╫"
  echo "      ████████▒▓█████▀       ]╫N  ╫╫∩ j╫Ñ  j╦¬ ╠╫H j╦r j╫Ñ  ╫╫░ :╫╫  j╫Ñ  ]╫Ñ  ╫╫∩ :╫╫"
  echo "      ████████████▓▀         'Ñ╫NN╬╫∩  ╚╫N╦╫M   ╩╫NÑÑ  j╫Ñ  ╙ÑÑ╦Ñ╫╫  j╫Ñ  ]╫Ñ  ╫╫∩ :╫╫"
  echo "************************************************************************************************"
}

function start_banner {
  ascii_banner
  echo "                                  Welcome to Decidim installation"
  echo "                                        This is a BETA"
  echo "          You should be aware that this could break your environment (if you have any)"
  echo "          This will install rbenv, postgresql, nodejs and install decidim on this directory"
  echo "                It'll take from 10 to 30 minutes depending on your network connection"
  echo "************************************************************************************************"

  echo "Starting on 60 seconds. Press CTRL+C to cancel" 
  sleep 60
}

function end_banner {
  ascii_banner
  echo "                     Decidim installation process finished. All is OK!"
  echo "************************************************************************************************"
  echo "                  You can go to http://localhost:3000 and see the website."
  echo "              It'll take a few minutes to start up the first time. Be patient. "
  echo "************************************************************************************************"
  echo "   ------------------------------------------------------------------------------------------"
  echo "  | Email              | Password      | URL                               | Role           |"
  echo "   ------------------------------------------------------------------------------------------"
  echo "  | user@example.org   | decidim123456 | http://localhost:3000/session/new | Regular user   |"
  echo "  | admin@example.org  | decidim123456 | http://localhost:3000/admin       | Admin user     |"
  echo "   ------------------------------------------------------------------------------------------"
  echo "************************************************************************************************"
  read -p "Press any key to continue: " -n 1 -r
}

function check_root {
  if [ "$(id -u)" == "0" ] ; then
     echo "This script must not be run as root" 1>&2
     exit 1
  fi
}

function check_git_config {
  if [ $(git config -l | wc -l) == 0 ] ; then 
    echo "Configure git and execute again"
    echo 'git config --global user.email "you@example.com"'
    echo 'git config --global user.name "Your Name"'
    exit 2
  fi 
}

### macos

function install_ruby_macos {
  if [ ! -f /usr/local/bin/rbenv ] ; then
    brew install rbenv ruby-build
    echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bash_profile
    source ~/.bash_profile
    rbenv install $RUBY_VERSION
    rbenv global $RUBY_VERSION
    echo "gem: --no-document" > ~/.gemrc
    gem install bundler
  fi
}

### Ubuntu

function install_ruby_ubuntu {
  if [ ! -d ~/.rbenv ] ; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    rbenv install $RUBY_VERSION
    rbenv global $RUBY_VERSION
    echo "gem: --no-document" > ~/.gemrc
    gem install bundler
  fi
}

### Shared

function install_decidim {
  gem install decidim
  decidim ${DECIDIM_DIR}
  cd ${DECIDIM_DIR}
  bundle install
  git init
  git add .
  git commit -m "Initial installation with Decidim (https://decidim.org)"
  cd -
}

function configure_db {
  cd ${DECIDIM_DIR}
  echo "gem 'figaro'" >> Gemfile
  bundle install
  bundle exec figaro install
  cat <<EOF > config/application.yml
DATABASE_USERNAME: ${DB_USER}
DATABASE_PASSWORD: ${DB_PASS}
EOF
  cd - 
}

function migrate_db {
  cd ${DECIDIM_DIR}
  bin/rails db:create db:migrate db:seed
  cd - 
}

function start_decidim {
  cd ${DECIDIM_DIR}
  bin/rails server
}

function cleanup {
  rm -rf ${DECIDIM_DIR}
  psql -c "DROP DATABASE IF EXISTS decidim_application_development;"
  psql -c "DROP DATABASE IF EXISTS decidim_application_test;"
  psql -c "DROP ROLE IF EXISTS decidim_app;"
}

function install_all_ubuntu {

  sudo apt-get update

  # Installs development tools
  sudo apt-get install -y build-essential autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev

  # Installs Ruby
  install_ruby_ubuntu

  # Installs and configures PostgreSQL
  sudo apt-get install -y postgresql libpq-dev
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH CREATEROLE SUPERUSER CREATEDB;"
  sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

  # Installs nodejs
  curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash -
  sudo apt-get install -y nodejs

  # Installs imagemagick library 
  sudo apt-get install -y imagemagick

}

function install_all_macos {

  # Installs xcode
  xcode-select -p 2> /dev/null || xcode-select --install 2> /dev/null

  # Installs Brew
  if [ ! -f /usr/local/bin/brew ] ; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    brew update
  fi

  # Installs Ruby
  install_ruby_macos
  
  # Installs and configures PostgreSQL
  brew install postgres
  sleep 5
  nohup postgres -D /usr/local/var/postgres  &
  sleep 5
  createdb $(whoami) || true
  psql -c "CREATE USER ${DB_USER} WITH CREATEROLE SUPERUSER CREATEDB;"
  psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

  # Installs imagemagick library 
  brew install imagemagick

}

function main {
  start_banner
  #cleanup ${DECIDIM_DIR}
  check_root
  check_git_config

  OS="`uname`"
  case $OS in
    'Linux')
      echo "Installing dependencies for Ubuntu ..."
      install_all_ubuntu
      echo "Cloning decidim ..."
      install_decidim
      echo "Configuring database ..."
      configure_db 
      migrate_db
      end_banner
      start_decidim
      ;;
    'Darwin')
      echo "Installing dependencies for macos ..."
      install_all_macos
      echo "Cloning decidim ..."
      install_decidim
      echo "Configuring database ..."
      migrate_db
      end_banner
      start_decidim
      ;;
    *)
      "Operating System Not Supported"
      exit 2
      ;;
  esac

  exit 0
}

main
