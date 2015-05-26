#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                         #
# build-atlassian-confluence.sh                           #
# This script will build a debian package (.deb) of       #
# Atlassian Confluence.                                   #
#                                                         #
# Author: Rico Ullmann                                    #
# web: https://erinnerungsfragmente.de                    #
# github: https://github.com/rullmann                     #
#                                                         #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

### Define variables

# Confluence home dir. This is where the data (e.g. attachments) will be stored.
CONFLUENCE_HOME="/var/opt/confluence"

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
    echo -e "No filename has been supplied.\nUsage: ./build-atlassian-confluence.sh atlassian-confluence-5.7.4.tar.gz\n"
    exit 1
fi

# It should be a file
if [ ! -f $INPUT_FILE ] ; then
    echo -e "$1 does not seem to be a valid file.\n Put it into $BASE_DIR/$SETUP_DIR.\n"
    exit 1
fi

# Does it contain confluence?
echo -e "$INPUT_FILE\n" | grep -i confluence
if [ $? -eq 1 ] ; then
    echo -e "The provided filename ($1) must contain confluence.\n"
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

CONFLUENCE_DIR="$BASE_DIR/$WORK_DIR/$(ls $BASE_DIR/$WORK_DIR/)"
CONFLUENCE_FOLDER=$(ls $BASE_DIR/$WORK_DIR/)
CONFLUENCE_VERSION=$(ls $BASE_DIR/$WORK_DIR/ | sed "s/atlassian-confluence-//")

# Set our data directory
cat > "$CONFLUENCE_DIR/confluence/WEB-INF/classes/confluence-init.properties" << EOT
###########################
# Configuration Directory #
###########################

confluence.home=$CONFLUENCE_HOME
EOT

# Modify the setenv.sh to give it enough memory etc.

cat <<'EOF' > "$CONFLUENCE_DIR/bin/setenv.sh"
# See the CATALINA_OPTS below for tuning the JVM arguments used to start Confluence.

echo "If you encounter issues starting up Confluence, please see the Installation guide at http://confluence.atlassian.com/display/DOC/Confluence+Installation+Guide"

# set the location of the pid file
if [ -z "$CATALINA_PID" ] ; then
    if [ -n "$CATALINA_BASE" ] ; then
        CATALINA_PID="$CATALINA_BASE"/work/catalina.pid
    elif [ -n "$CATALINA_HOME" ] ; then
        CATALINA_PID="$CATALINA_HOME"/work/catalina.pid
    fi
fi
export CATALINA_PID

PRGDIR=`dirname "$0"`
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

# Set the JVM arguments used to start Confluence. For a description of the options, see
# http://www.oracle.com/technetwork/java/javase/tech/vmoptions-jsp-140102.html
CATALINA_OPTS="-XX:-PrintGCDetails -XX:+PrintGCTimeStamps -XX:-PrintTenuringDistribution ${CATALINA_OPTS}"
CATALINA_OPTS="-Xloggc:$LOGBASEABS/logs/gc-'`date +%F_%H-%M-%S`'.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=2M ${CATALINA_OPTS}"
CATALINA_OPTS="-Djava.awt.headless=true ${CATALINA_OPTS}"
CATALINA_OPTS="-Xms1536m -Xmx1536m -XX:MaxPermSize=384m -XX:+UseG1GC ${CATALINA_OPTS}"
export CATALINA_OPTS

JRE_HOME="/opt/java_current/jre"; export JRE_HOME
EOF

cat <<'EOF' > "$CONFLUENCE_DIR/conf/server.xml"
<Server port="8000" shutdown="SHUTDOWN" debug="0">
    <Service name="Tomcat-Standalone">
        <Connector port="8090" connectionTimeout="20000" redirectPort="8443"
                maxThreads="200" minSpareThreads="10"
                enableLookups="false" acceptCount="10" debug="0" URIEncoding="UTF-8" />

        <Engine name="Standalone" defaultHost="localhost" debug="0">

            <Host name="localhost" debug="0" appBase="webapps" unpackWARs="true" autoDeploy="false">

                <Context path="" docBase="../confluence" debug="0" reloadable="false" useHttpOnly="true">
                    <Manager pathname="" />
                </Context>
            </Host>

        </Engine>
    </Service>
</Server>
EOF

cat <<'EOF' > "$CONFLUENCE_DIR/bin/user.sh" 
# START INSTALLER MAGIC ! DO NOT EDIT !
CONF_USER="confluence" ##
# END INSTALLER MAGIC ! DO NOT EDIT !

export CONF_USER
EOF

# Download the MySQL J Connector
wget -O $BASE_DIR/$WORK_DIR/mysqlj.zip https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.35.zip
unzip $BASE_DIR/$WORK_DIR/mysqlj.zip -d $BASE_DIR/$WORK_DIR/
cp $BASE_DIR/$WORK_DIR/mysql-connector-java-*/mysql-connector-java-*-bin.jar $CONFLUENCE_DIR/confluence/WEB-INF/lib/

# Add the Java install script for post installation

wget -O $CONFLUENCE_DIR/oracle_java_install.sh https://raw.githubusercontent.com/rullmann/scripts/master/oracle_java_install.sh

### Prepare the build process

# Pack everything together
cd $CONFLUENCE_DIR &&  tar czf $BASE_DIR/$WORK_DIR/$(echo $CONFLUENCE_FOLDER | sed "s/atlassian-confluence-/atlassian-confluence_/g").orig.tar.gz *
cd $BASE_DIR

# Copy debian folder to work dir, as we have to change some stuff.
cp -R debian $CONFLUENCE_DIR
cd $CONFLUENCE_DIR/debian

# Changelog must contain the Confluence version we'd like to distribute
cat > "changelog" << EOT
atlassian-confluence ($CONFLUENCE_VERSION) trusty; urgency=medium

  * Atlassian Confluence $CONFLUENCE_VERSION

 -- Rico Ullmann <rico@erinnerungsfragmente.de>  $(LANG=C date -R)
EOT

# We have to regenerate the md5sums for obvious reasons
md5sum defaults.template > defaults.md5sum
md5sum logrotate.template > logrotate.md5sum

# Let's build!
cd $CONFLUENCE_DIR
dpkg-buildpackage -us -uc