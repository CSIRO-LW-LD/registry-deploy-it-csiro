#!/bin/bash
set -e

RELEASE=snapshot/com/github/ukgovld/registry-core/0.0.2-SNAPSHOT/registry-core-0.0.2-20131118.120346-3.war

sysv-rc-conf tomcat7 on

# No attached volume, just just create empty ldregistry areas
if [ ! -d "/opt/ldregistry" ]; then
  mkdir /opt/ldregistry
  chown tomcat7 /opt/ldregistry
fi
if [ ! -d "/var/opt/ldregistry" ]; then
  mkdir /var/opt/ldregistry
  chown tomcat7 /var/opt/ldregistry
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
#sudo su
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
