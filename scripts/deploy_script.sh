#!/bin/bash

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

# update the Penelope configuration URL of the WebAPI
perl -i -pe "BEGIN{undef $/;} s|http://localhost:8080|"$WEBAPI_URL"|g" /usr/local/tomcat/webapps/penelope/web/js/app.js

# load any jdbc drivers in the docker host volume mapped directory into the tomcat library
cp /tmp/drivers/*.jar /usr/local/tomcat/lib

# start tomcat
/usr/local/tomcat/bin/catalina.sh run
