# Installation directions

This instruction is for Mac OSX. Please kindly contribute for the Linux or Windows version.

## MacOSX (Yosemite)

### Apache, MySQL 

To set up locally the bawi-on-perl setting, first we need to setup the Apache and MySQL setup.
For convenience, we will use the user based directory instead of the DocumentRoot.

The following link is very useful:

http://coolestguidesontheplanet.com/get-apache-mysql-php-phpmyadmin-working-osx-10-10-yosemite/

* You can skip anything related to PHP. Not necessary.
* installed MySQL 5.6.27. (I just chose to automatically start on boot)
* Note that for mysql root set up, do not put the password on command line.
* Also uncomment LoadModule cgi_module libexec/apache2/mod_cgi.so in httpd.conf
* Edit /etc/apache2/users/[username].conf

```
<Directory "/Users/[username]/Sites/">
    AllowOverride All
    AddHandler cgi-script .cgi
    Options Indexes MultiViews SymLinksIfOwnerMatch Includes ExecCGI
    DirectoryIndex index.html index.cgi
    Require all granted
</Directory>
```

At this point, you should be able to access the local website by typing `http://127.0.0.1/~[username]/` on your preferred browser.

You can test whether perl based script is working by writing the code to Sites directory:

```
cd ~/Sites/
vi test.cgi

#!/usr/bin/perl -w

use strict;
use warnings;

print qq(Content-type: text/plain\n\n);

print "Hello Perl World!\n";
```

then type on your browser `http://127.0.0.1/~[username]/test.cgi` on your preferred browser.


### GIT clone the code

Go to the user based directory
```
cd ~/Sites/
git clone https://github.com/bawi/bawi-on-perl.git local
```

Note that the [master] branch has not been merged for long time, and the acting server branch is [sync], but detached from HEAD. That means that any testing that you do on your [local] branch (or derivatives) will have to be merged carefully to the [sync] branch.

Once you have the code on your directory, first thing is to make configuration files from sample files.
```
cd ~/Sites/bawi-on-perl/conf
ls *.sample | awk '{print("cp "$1" "$1)}' | sed 's/.sample//2'
ls *.sample | awk '{print("cp "$1" "$1)}' | sed 's/.sample//2' | /bin/sh
```

Now we will set up the mysql databases and then correctly configure the configuration files.
I assume that MySQL has been set up at the Apache2, MySQL installation section and have the root user set up.

### mysql database setup

db/bawi.sql has the most up-to-date table schema of the running bawi system (and other things as well, may need to trim).

```
mysql -u root -p
mysql>create database bawi;
mysql>create user 'bawi'@'localhost' identified by '[MySQL password]';
mysql>grant all privileges on *.* to 'bawi'@'localhost' with grant option;
mysql>exit

mysql -u bawi -p bawi < ~/Sites/bawi-on-perl/db/bawi.sql
```
(You can use different DBUser name or DB name, just change the configuration file accordingly)

Based on the MySQL database and user/password, now you can configure board.conf, main.conf, user.conf
Specifically, you need to change

```
DBName bawi
DBUser bawi
DBpasswd [your MySQL password]

SessionName   bawi_session_local # something that does not interfere with other applications
SessionDomain dev.bawi.org
```

It is very important to set up the SessionDomain right. Currently I have set as dev.bawi.org (later I will add this in other settings), but if you want another name, do not forget to change the three files accordingly (board.conf, main.conf, user.conf).

### Installing necessary perl modules

We will eventually run the startup.pl in apache2/ folder for virtual hosting for mod_perl Apache, but to test whether all necessary Perl modules are installed in the system, let us run in shell the CGI scripts first. For that, you need to manually set up some environment variables (that works in only one shell session. You could put it in .bash_profile if you want)

```
cd ~/Sites/bawi-on-perl/
export BAWI_PERL_HOME=~/Sites/bawi-on-perl
export BAWI_DATA_HOME=~/Sites/bawi-on-perl
```

One way to check whether necessary perl modules are intact is to try to run one CGI script and see what error it emits.

```
cd ~/Sites/bawi-on-perl/main/
./index.cgi
```

For the first time, most of the perl modules will not be installed. So let us do one by one by testing the above cgi script and running it and installing it.

```
sudo cpan HTML::Template
sudo cpan Text::Iconv
sudo cpan DBI
sudo cpan Apache::DBI
```

For the first time, cpan wants to have the configuration setup. You are given the choice of installing perl modules locally (local::lib) option or doing with superuser. I have not explored the local library option which might be better.

One tricky installation is the DBI::mysql package. General consensus seems to suggest that on Mac system, compile with a *defined* Perl version to avoid any break during an (automatic) update of OSX. Honestly I am fine with Yosemite and we are going to test a small CGI script code cohort, so I moved on without considering the fixed Perl version (We could re-install it I believe).

The strategy for the install of DBI::mysql package is to source install and soft link the resulting libraries to a general path.

See some informations:

* http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod#Mac_OS_X
* https://movabletype.org/documentation/installation/osx-10-9.html
* http://www.ensembl.info/blog/2013/09/09/installing-perl-dbdmysql-and-ensembl-on-osx/ 
* http://bixsolutions.net/forum/thread-8.html

Hope you can follow from here what I have done:
```
# This is tricky part
# See: http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod#Mac_OS_X
perl -MCPAN -e 'shell'
cpan>get DBD::mysql
cpan>exit

cd ~/.cpan/build/DBD-mysql-4.032-6_SVJx/ # what ever the version is probably different directory name. Use Tab to figure out

perl Makefile.PL --mysql_config=/usr/local/mysql-5.6.16-osx10.7-x86_64/bin/mysql_config # whatever the version it is. Mine is 5.6.27.

make

export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:/usr/local/mysql-5.6.27-osx10.8-x86_64/lib/  # what ever the version is

make test

sudo make install

# For us, it might be easier to just link the libmysqlclient.18.dylib (why we defined the DYLD_LIBRARY_PATH) by soft link.
sudo ln -s /usr/local/mysql/lib/libmysqlclient.18.dylib /usr/lib/libmysqlclient.18.dylib
```

This will set up the DBI::mysql to the proper mysql. You can check that by again running the main index.cgi script on shell.


### Set up the virtual hosting

Now we are ready to set up the virtual hosting. That is to say, instead of running it like "http://localhost/~WWolf/index.cgi" we have a virtual domain name (only used by ourselves). For convenience, I have set up dev.bawi.org. 

The code should run independent of whatever domain we are using except for a few archaic predefined URLs (which is not critical). To remedy this, there is one difference (as of now) from the sync branch to the local branch, about the defaults. By `cd ~/Sites/bawi-on-perl; grep -R dev.bawi.org .` you will easily figure out the code.

Majority of virtual hosting apache configuration is pre-written in apache2/bawi-spring configuration file. Using superuser privileges, we will link vhosts file that the apache2 configuration file is including to this file. So any configuration we need to edit the apache2/bawi-spring configuration.

Finally, although most of the Bawi code is essentially CGI program and we can interrogate the workings on shell, there is a thin wrap where mod_perl comes in, and it has to do with the apache2/bawi-spring configuration file. That is, we want to define the BAWI_PERL_HOME environment variable by using a small mod_perl snippet run every time Apache restarts. So edit of the apache2/startup.pl is also important.

So first, let us have mod_perl installed in Apache. Follow the steps in the link, but a brief summary described below.

* See: http://blog.n42designs.com/blog/2014/10/23/compiling-mod-perl-for-apache-2-dot-4-on-os-x-10-dot-10-yosemite/

```
cd ~
svn checkout https://svn.apache.org/repos/asf/perl/modperl/trunk/ mod_perl-2.0
cd mod_perl-2.0
# assume you already have XCode6.1 installed
/usr/bin/apr-1-config --includedir /usr/include/apr-1
sudo ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/usr/include/apache2 /usr/include/apache2
sudo ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/usr/include/apr-1 /usr/include/apr-1
perl Makefile.PL MP_CCOPTS=-std=gnu89 ; make ; sudo make install
sudo vi /etc/apache2/httpd.conf
# now include the mod_perl line
# LoadModule perl_module libexec/apache2/mod_perl.so
sudo apachectl configtest
sudo apachectl restart
```

Now, we have to configure the virtual host setting. What we are going to do is to soft link the httpd-vhosts.conf file to the already set up file in apache2/ directory. Follow below.

```
cd /etc/apache2/extra
sudo mv httpd-vhosts.conf httpd-vhosts.conf.original
sudo ln -s ~/Sites/bawi-on-perl/apache2/bawi-spring httpd-vhosts.conf
```

Now, fix the apache2/bawi-spring file to have the correct path. Also, fix the startup.pl path (hold on for the data directory for a minute).

```
# For bawi-spring file in bawi-on-perl/apache2
# Change everything that is bawi.org to dev.bawi.org
# Change everything that is /home/bawi/bawi-spring/ to whatever your absolute path such as /Users/WWolf/Sites/bawi-on-perl/
## for vi, that is using substitution arguments. But you will figure out with your preferred editor.

# For startup.pl in bawi-on-perl/apache2
# change the first line path to *absolute* path. This is totally necessary
# change all the BAWI_PERL_HOME and BAWI_DATA_HOME path to your absolute path
```

When everything is done, restart the apache server
```
sudo apachectl restart
```

Then finally, change the hosts file
```
sudo vi /etc/hosts
# include one line with
127.0.0.1 dev.bawi.org
```

Now, type in on your browser dev.bawi.org.

Voila!

### Database sampler

Now we have the first page on-line. But we do not have any users and any databases, so we have to make one.

A easy way is to make a sampler from the existing database. Because of security reasons, if anyone request a sampler database, I can pick up *only* that requester by performing mysqldump on minimally required tables. (Of course, WWolf is my ID, will be replaced to your bawi id) :

```
mysqldump --opt --user=bawi -p bawi bw_xauth_passwd --where="id='WWolf'" >> sampler.sql
mysqldump --opt --user=bawi -p bawi bw_user_basic --where="uid=[the requesters id]" >> sampler.sql
mysqldump --opt --user=bawi -p bawi bw_user_ki --where ="uid=[the requesters id]" >> sampler.sql
``` 

### Installing Image::Magick

After this, you will be able to get into the first main page (after updating your personal information). There is one more Perl module left which is Image::Magick, used scarcely in image boards and so makes error. Let us install it (which is again a bit tricky in Mac OSX).

This is another beast, but essentially source install.
http://www.imagemagick.org/script/perl-magick.php

```
cd ~/Sites
curl -O http://www.imagemagick.org/download/ImageMagick.tar.gz
tar xvzf ImageMagick.tar.gz
cd ImageMagick-6.9.2-4/ # whatever version it is.
./configure -with-perl
make
sudo make install # takes pretty long time...
sudo ldconfig /usr/local/lib # really necessary? (did not do)
perl -e "use Image::Magick; print Image::Magick->QuantumDepth"  # just for testing
sudo apachectl restart # necessary once.
```

### Now, the empty Bawi (local) world.

Congratulations! You are now able to explore the empty barren world of bawi-on-perl.
If you want to just test the behavior of CSS, please use `http://dev.bawi.org/board/addboard.cgi` to make a board for yourself and subscribe.

### Exploration of CSS skins etc.

The basic structure of bawi-on-perl is simple. Just as a quick guide, there are three different skins themes, but the major ones you may care is in `board/skin/` directory. For HTML templates, they are in `board/templates/`. Once you edit the templates and test CSS, and check on the web you will adapt fairly easy how things are working.

Thanks for following this road to make Bawi a better place.


-- WWolf



