#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                         #
# build-atlassian-jira.sh                                 #
# This script will build a debian package (.deb) of       #
# Atlassian JIRA.                                         #
#                                                         #
# Author: Rico Ullmann                                    #
# web: https://erinnerungsfragmente.de                    #
# github: https://github.com/rullmann                     #
#                                                         #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

### Define variables

# JIRA home dir. This is where the data (e.g. attachments) will be stored.
JIRA_HOME="/var/opt/jira"

# Define our base dir where files are being stored
BASE_DIR="$(pwd)"

# Official downloads
SETUP_DIR="setup-files"

# Where to store temporary files. e.g. the unpacked directory
WORK_DIR="tmp"

INPUT_FILE="$BASE_DIR/$SETUP_DIR/$1"

### Create directories if they don't exist

mkdir -p $BASE_DIR && mkdir -p $BASE_DIR/$SETUP_DIR && mkdir -p $BASE_DIR/$WORK_DIR

### Check variable

# Argument present?
if [ -z "$1" ]; then
    echo -e "No filename has been supplied.\nUsage: ./build-atlassian-jira.sh atlassian-jira-6.4.6.tar.gz\n"
    exit 1
fi

# It should be a file
if [ ! -f $INPUT_FILE ] ; then
    echo -e "$1 does not seem to be a valid file.\n Put it into $BASE_DIR/$SETUP_DIR.\n"
    exit 1
fi

# Does it contain jira?
echo -e "$INPUT_FILE\n" | grep -i jira
if [ $? -eq 1 ] ; then
    echo -e "The provided filename ($1) must contain jira.\n"
    exit 1
fi

# Is it gzip?
if file --mime-type $INPUT_FILE | grep -q gzip$; then
    echo -e "File seems to be fine. Will move on and build the deb.\n"
else
    echo -e "Something seems to be wrong here. File is not a gzip.\n"
    exit 1
fi

### Prepare the setup files

cd $BASE_DIR

# Later we should check if tmp is empty! #

# Unpack the archive
tar -xzf $INPUT_FILE -C $BASE_DIR/$WORK_DIR/

JIRA_ORIG_DIR="$BASE_DIR/$WORK_DIR/$(ls $BASE_DIR/$WORK_DIR/)"
JIRA_VERSION=$(ls $BASE_DIR/$WORK_DIR/ | sed "s/atlassian-jira-//" | sed "s/-standalone//")

mv $JIRA_ORIG_DIR $BASE_DIR/$WORK_DIR/atlassian-jira-$JIRA_VERSION

JIRA_FOLDER=$(ls $BASE_DIR/$WORK_DIR/)
JIRA_DIR="$BASE_DIR/$WORK_DIR/$(ls $BASE_DIR/$WORK_DIR/)"

# Set our data directory
cat > "$JIRA_DIR/atlassian-jira/WEB-INF/classes/jira-application.properties" << EOT
###########################
# Configuration Directory #
###########################

jira.home=$JIRA_HOME
EOT

# Modify the setenv.sh to give it enough memory etc.

cat <<'EOF' > "$JIRA_DIR/bin/setenv.sh"
#
#  Occasionally Atlassian Support may recommend that you set some specific JVM arguments.  You can use this variable below to do that.
#
JVM_SUPPORT_RECOMMENDED_ARGS="-XX:+UseParallelOldGC"

#
# The following 2 settings control the minimum and maximum given to the JIRA Java virtual machine.  In larger JIRA instances, the maximum amount will need to be increased.
#
JVM_MINIMUM_MEMORY="1024m"
JVM_MAXIMUM_MEMORY="1536m"

#
# The following are the required arguments for JIRA.
#
JVM_REQUIRED_ARGS='-Djava.awt.headless=true -Datlassian.standalone=JIRA -Dorg.apache.jasper.runtime.BodyContentImpl.LIMIT_BUFFER=true -Dmail.mime.decodeparameters=true -Dorg.dom4j.factory=com.atlassian.core.xml.InterningDocumentFactory'

# Uncomment this setting if you want to import data without notifications
#
#DISABLE_NOTIFICATIONS=" -Datlassian.mail.senddisabled=true -Datlassian.mail.fetchdisabled=true -Datlassian.mail.popdisabled=true"


#-----------------------------------------------------------------------------------
#
# In general don't make changes below here
#
#-----------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------
# This allows us to actually debug GC related issues by correlating timestamps
# with other parts of the application logs.  The second option prevents the JVM
# from suppressing stack traces if a given type of exception occurs frequently,
# which could make it harder for support to diagnose a problem.
#-----------------------------------------------------------------------------------
JVM_EXTRA_ARGS="-XX:+PrintGCDateStamps -XX:-OmitStackTraceInFastThrow"

PRGDIR=`dirname "$0"`
cat "${PRGDIR}"/jirabanner.txt

JIRA_HOME_MINUSD=""
if [ "$JIRA_HOME" != "" ]; then
    echo $JIRA_HOME | grep -q " "
    if [ $? -eq 0 ]; then
        echo ""
        echo "--------------------------------------------------------------------------------------------------------------------"
        echo "   WARNING : You cannot have a JIRA_HOME environment variable set with spaces in it.  This variable is being ignored"
        echo "--------------------------------------------------------------------------------------------------------------------"
    else
        JIRA_HOME_MINUSD=-Djira.home=$JIRA_HOME
    fi
fi

JAVA_OPTS="-Xms${JVM_MINIMUM_MEMORY} -Xmx${JVM_MAXIMUM_MEMORY} ${JAVA_OPTS} ${JVM_REQUIRED_ARGS} ${DISABLE_NOTIFICATIONS} ${JVM_SUPPORT_RECOMMENDED_ARGS} ${JVM_EXTRA_ARGS} ${JIRA_HOME_MINUSD}"

# Perm Gen size needs to be increased if encountering OutOfMemoryError: PermGen problems. Specifying PermGen size is not valid on IBM JDKs
JIRA_MAX_PERM_SIZE=384m
if [ -f "${PRGDIR}/permgen.sh" ]; then
    echo "Detecting JVM PermGen support..."
    . "${PRGDIR}/permgen.sh"
    if [ $JAVA_PERMGEN_SUPPORTED = "true" ]; then
        echo "PermGen switch is supported. Setting to ${JIRA_MAX_PERM_SIZE}"
        JAVA_OPTS="-XX:MaxPermSize=${JIRA_MAX_PERM_SIZE} ${JAVA_OPTS}"
    else
        echo "PermGen switch is NOT supported and will NOT be set automatically."
    fi
fi

export JAVA_OPTS

echo ""
echo "If you encounter issues starting or stopping JIRA, please see the Troubleshooting guide at http://confluence.atlassian.com/display/JIRA/Installation+Troubleshooting+Guide"
echo ""
if [ "$JIRA_HOME_MINUSD" != "" ]; then
    echo "Using JIRA_HOME:       $JIRA_HOME"
fi

# set the location of the pid file
if [ -z "$CATALINA_PID" ] ; then
    if [ -n "$CATALINA_BASE" ] ; then
        CATALINA_PID="$CATALINA_BASE"/work/catalina.pid
    elif [ -n "$CATALINA_HOME" ] ; then
        CATALINA_PID="$CATALINA_HOME"/work/catalina.pid
    fi
fi
export CATALINA_PID

if [ -z "$CATALINA_BASE" ]; then
  if [ -z "$CATALINA_HOME" ]; then
    LOGBASE=$PRGDIR
    LOGTAIL=..
  else
    LOGBASE=$CATALINA_HOME
    LOGTAIL=.
  fi
else
  LOGBASE=$CATALINA_BASE
  LOGTAIL=.
fi

PUSHED_DIR=`pwd`
cd $LOGBASE
cd $LOGTAIL
LOGBASEABS=`pwd`
cd $PUSHED_DIR

echo ""
echo "Server startup logs are located in $LOGBASEABS/logs/catalina.out"
EOF

echo 'JRE_HOME="/opt/java_current/jre"; export JRE_HOME' | cat - "$JIRA_DIR/bin/catalina.sh" | tee "$JIRA_DIR/bin/catalina.sh" > /dev/null 2>&1


cat <<'EOF' > "$JIRA_DIR/conf/server.xml"
<?xml version="1.0" encoding="utf-8"?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
<Server port="8005" shutdown="SHUTDOWN">

    <!--APR library loader. Documentation at /docs/apr.html -->
    <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on"/>
    <!--Initialize Jasper prior to webapps are loaded. Documentation at /docs/jasper-howto.html -->
    <Listener className="org.apache.catalina.core.JasperListener"/>
    <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener"/>

    <Service name="Catalina">

        <Connector port="8080"

                   maxThreads="200"
                   minSpareThreads="25"
                   connectionTimeout="20000"

                   enableLookups="false"
                   maxHttpHeaderSize="8192"
                   protocol="HTTP/1.1"
                   useBodyEncodingForURI="true"
                   redirectPort="8443"
                   acceptCount="100"
                   disableUploadTimeout="true"/>

        <Engine name="Catalina" defaultHost="localhost">
            <Host name="localhost" appBase="webapps" unpackWARs="true" autoDeploy="true">

                <Context path="" docBase="${catalina.home}/atlassian-jira" reloadable="false" useHttpOnly="true">

                    <Resource name="UserTransaction" auth="Container" type="javax.transaction.UserTransaction"
                              factory="org.objectweb.jotm.UserTransactionFactory" jotm.timeout="60"/>
                    <Manager pathname=""/>
                </Context>

            </Host>

            <Valve className="org.apache.catalina.valves.AccessLogValve" resolveHosts="false"
                   pattern="%a %{jira.request.id}r %{jira.request.username}r %t &quot;%m %U%q %H&quot; %s %b %D &quot;%{Referer}i&quot; &quot;%{User-Agent}i&quot; &quot;%{jira.request.assession.id}r&quot;"/>

        </Engine>
    </Service>
</Server>
EOF

cat <<'EOF' > "$JIRA_DIR/bin/user.sh" 
# START INSTALLER MAGIC ! DO NOT EDIT !
JIRA_USER="jira" ##
# END INSTALLER MAGIC ! DO NOT EDIT !

export JIRA_USER
EOF

# Download the MySQL J Connector
wget -O $BASE_DIR/$WORK_DIR/mysqlj.zip https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.35.zip
unzip $BASE_DIR/$WORK_DIR/mysqlj.zip -d $BASE_DIR/$WORK_DIR/
cp $BASE_DIR/$WORK_DIR/mysql-connector-java-*/mysql-connector-java-*-bin.jar $JIRA_DIR/lib/

# Add the Java install script for post installation

wget -O $JIRA_DIR/oracle_java_install.sh https://raw.githubusercontent.com/rullmann/scripts/master/oracle_java_install.sh

### Prepare the build process

# Pack everything together
cd $JIRA_DIR &&  tar czf $BASE_DIR/$WORK_DIR/$(echo $JIRA_FOLDER | sed "s/atlassian-jira-/atlassian-jira_/g").orig.tar.gz *
cd $BASE_DIR

# Copy debian folder to work dir, as we have to change some stuff.
cp -R debian $JIRA_DIR
cd $JIRA_DIR/debian

# Changelog must contain the JIRA version we'd like to distribute
cat > "changelog" << EOT
atlassian-jira ($JIRA_VERSION) trusty; urgency=medium

  * Atlassian JIRA $JIRA_VERSION

 -- Rico Ullmann <rico@erinnerungsfragmente.de>  $(LANG=C date -R)
EOT

# We have to regenerate the md5sums for obvious reasons
md5sum defaults.template > defaults.md5sum
md5sum logrotate.template > logrotate.md5sum

# Let's build!
cd $JIRA_DIR
dpkg-buildpackage -us -uc
