#!/bin/bash
set -e

# Set up configuration area /opt/ldregistry
echo "** Installing registry application"
rm -rf /var/lib/tomcat7/webapps/ROOT*
#curl -4s https://s3-eu-west-1.amazonaws.com/ukgovld/$RELEASE > /var/lib/tomcat7/webapps/ROOT.war
#sudo su
service tomcat7 stop
rm -rf /var/opt/ldregistry/*
cd ~/
cd registry-core
git pull
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
