#!/bin/bash
set -e

RELEASE=snapshot/com/github/ukgovld/registry-core/0.0.2-SNAPSHOT/registry-core-0.0.2-20131118.120346-3.war

apt-get update -y
apt-get install -y --no-install-recommends curl sysv-rc-conf
apt-get install -y --no-install-recommends git 
apt-get install -y --no-install-recommends maven

# install and configure tomcat
echo "** Installing java and tomcat"
apt-get install -y --no-install-recommends tomcat7 language-pack-en
service tomcat7 stop

# tomcat7 on ubuntu seems hardwired to java-6 so have to dance around this
# installing java-7 first doesn't work and we end up with failures in tomcat startup
apt-get install -y --no-install-recommends openjdk-7-jdk 
update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
unlink /usr/lib/jvm/default-java
ln -s /usr/lib/jvm/java-1.7.0-openjdk-amd64 /usr/lib/jvm/default-java

if [ $(java -version 2>&1 | grep 1.7. -c) -ne 1 ]
then
  echo "**   ERROR: java version doesn't look right, try manual alternatives setting restart tomcat7"
  echo "**   java version is:"
  java -version
  exit 1
fi
service tomcat7 start
sysv-rc-conf tomcat7 on

# Configure runtime areas
if ! blkid | grep /dev/xvdf; then
  # No visible attached volume but might not be formatted yet
  # This will just fail on a local vm
  mkfs -t ext4 /dev/xvdf || true
fi

if blkid | grep /dev/xvdf; then
  # We have an attached volume, mount it
  if ! mount | grep /dev/xvdf ; then
    echo "/dev/xvdf /mnt ext4 rw 0 0" | tee -a /etc/fstab > /dev/null && mount /mnt  
  fi
  # If it's snapshot the ldregistry areas will exist, otherwise create them
  mkdir -p /mnt/opt/ldregistry 
  chown tomcat7 /mnt/opt/ldregistry
  
  mkdir -p /mnt/varopt/ldregistry
  chown tomcat7 /mnt/varopt/ldregistry

  if [ ! -d /opt/ldregistry ]; then
    ln -s /mnt/opt/ldregistry /opt
  fi
  if [ ! -d /var/opt/ldregistry ]; then
    ln -s /mnt/varopt/ldregistry /var/opt
  fi
else
  # No attached volume, just just create empty ldregistry areas
  if [ ! -d "/opt/ldregistry" ]; then
    mkdir /opt/ldregistry
    chown tomcat7 /opt/ldregistry
  fi
  if [ ! -d "/var/opt/ldregistry" ]; then
    mkdir /var/opt/ldregistry
    chown tomcat7 /var/opt/ldregistry
  fi
fi
# If the static ldregistry area is not already set up then clone from the vagrant synced folder
if [ ! -d "/opt/ldregistry/conf" ]; then
  cp -R /vagrant/ldregistry/* /opt/ldregistry
  chown -R  tomcat7 /opt/ldregistry/*
fi

if [ ! -d "/var/log/ldregistry" ]; then
  mkdir /var/log/ldregistry
  chown tomcat7 /var/log/ldregistry
fi

# install and configure nginx
echo "** Installing nginx"
apt-get install -y --no-install-recommends nginx
if [ $(grep -c nginx /etc/logrotate.conf) -ne 0 ]
then
  echo "**   logrotate for nginx already configured"
else
  cat /vagrant/install/nginx.logrotate.conf >> /etc/logrotate.conf
  echo "**   logrotate for nginx configured"
fi
cp /etc/nginx/sites-available/default  /etc/nginx/sites-available/original
cp /vagrant/install/nginx.conf /etc/nginx/sites-available/default

echo "**   starting nginx service ..."
service nginx restart
sysv-rc-conf nginx on

# Set up configuration area /opt/ldregistry
echo "** Installing registry application"
rm -rf /var/lib/tomcat7/webapps/ROOT*
#curl -4s https://s3-eu-west-1.amazonaws.com/ukgovld/$RELEASE > /var/lib/tomcat7/webapps/ROOT.war
sudo su
service tomcat7 stop
rm -rf /var/opt/ldregistry/*
cd ~/
git clone https://github.com/UKGovLD/registry-core.git
cd registry-core
mvn clean package
cd target
cp registry*.war /var/lib/tomcat7/webapps/ROOT.war
service tomcat7 start
service tomcat7 stop
rm -rf /var/opt/ldregistry/*
service tomcat7 start

if [ $(grep -c -e 'tomcat.*/opt/ldregistry/proxy-conf.sh' /etc/sudoers) -ne 0 ]
then
  echo "** sudoers already configured"
else
  cat /vagrant/install/sudoers.conf >> /etc/sudoers
  echo "** added sudoers access to proxy configuration"
fi
