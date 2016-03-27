# Installation directions

This instruction is for Mac OSX. Please kindly contribute for the Linux or Windows version.

## MacOSX (El Capitan)

El Capitan is different from Yosemite in that the root privileges is very strengthened. There are several ways to cope with this. One is using proprietary setup Docker. The other is to carefully install it the "right way". I will try to follow this.

### Apache

Installation is based on (El capitan):
http://coolestguidesontheplanet.com/get-apache-mysql-php-and-phpmyadmin-working-on-osx-10-11-el-capitan/

For safety, I will put everything I have done following the above mentioned link:

```
# For El capitan, Apache is default installed, need only to run on Terminal
sudo apachectl start
```

Set up the user-level configuration file. [username] is replaced by your actual username. You can check username by `whoami` command.
```
sudo vi /etc/apache2/users/[username].conf
<Directory "/Users/[username]/Sites/">
    AllowOverride All
    AddHandler cgi-script .cgi
    Options Indexes MultiViews SymLinksIfOwnerMatch Includes ExecCGI
    DirectoryIndex index.html index.cgi
    Require all granted
</Directory>
```

Check the permissions
```
-rw-r--r--  1 root  wheel  238 Dec 21 17:04 [username].conf
```

Let us not edit the apache2 configuration file. To do so,
```
sudo vi /etc/apache2/httpd.conf
```

Now search for modules for apache2, by searching the following lines and removing the "#" in front. First two should be already uncommented.

```
LoadModule authz_core_module libexec/apache2/mod_authz_core.so
```

```
LoadModule authz_host_module libexec/apache2/mod_authz_host.so
```

```
LoadModule userdir_module libexec/apache2/mod_userdir.so
```

```
LoadModule include_module libexec/apache2/mod_include.so
```

```
LoadModule rewrite_module libexec/apache2/mod_rewrite.so
```

Also, install mod_cgi, because this is what is explicitly used in bawi-on-perl.
```
LoadModule cgi_module libexec/apache2/mod_cgi.so
```

You do not need to have php running uncomment (if you are curious of the difference from the guidebook)


Now also uncomment user home directory
```
Include /private/etc/apache2/extra/httpd-userdir.conf
```

Now let us edit the userdirectory specific configuration file that we just uncommented.

```
sudo vi /etc/apache2/extra/httpd-userdir.conf
```

Now uncomment
```
Include /private/etc/apache2/users/*.conf
```

This will ensure that our [username].conf is now read.

Restart apache.
```
sudo apachectl restart
```

Now test on your web browser whether
```
http://localhost/~[username]/
```

will show up the (empty) directory structure.


### MySQL

To isolate all configuration (except apache installation that we have done successfully above), we will install mysql using homebrew. Homebrew is "the" package manager for Mac OSX: http://brew.sh/
(Useful link: http://coolestguidesontheplanet.com/installing-homebrew-on-os-x-el-capitan-10-11-package-manager-for-unix-apps/ )


``` 
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew doctor
brew update
```

-----------------------------------
Homebrew installs all packages in /usr/local/Cellar so that it is effectively isolated. It involves less of superadmin privileges. The following configuration is based on https://gist.github.com/kevinelliott/e12aa642a8388baf2499

If you want to install MySQL system-wide, skip this section and download and install MySQL via the following link:

http://dev.mysql.com/downloads/file/?id=459872

Everything else, refer to the old Yosemite installation instructions.
-----------------------------------

Now via homebrew, install mysql
```
brew install mysql  # for this installation instruction, I was installation 5.7.9.
brew pin mysql # if you want to just keep mysql at this version... really not necessary

# Copy launch agent into place
mkdir -p ~/Library/LaunchAgents && cp /usr/local/Cellar/mysql/VERSION/homebrew.mxcl.mysql.plist ~/Library/LaunchAgents/

# Edit launch agent and set both keepalive and launch at startup to false
vi ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist

# Inject launch agent
launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist

# Set up databases to run as your user account. This will also generate a temporary root account password you have to copy
mysqld --initialize --user=`whoami` --basedir="$(brew --prefix mysql)" --datadir =/usr/local/var/mysql

# Start mysql
mysql.server start
```

Now change the root password for the mysql server. This is simply changing the temporary password you have to something that you can remember. Note that you do not need to change it to the same password you have for your machine; recommended not to because the mysql password may be breached easily.

```
mysqladmin -u root -p password
mysqladmin: [Warning] Using a password on the command line interface can be insecure.
New password: 
Confirm new password: 
Warning: Since password will be sent to server in plain text, use ssl connection to ensure password safety.
```

That is it!


## GIT clone the code

Now, let us put the code here
cd ~/Sites/
git clone https://github.com/bawi/bawi-on-perl.git -b local

--------------------------------------------------------
(Tip) Note that the [master] branch has not been merged for long time (tag: [original_code]), and the production server runs with the [sync] branch with minor modifications that you can track by the log. [local] branch is a branch from the [sync] branch, with very few modifications as yet, and the initial working installation instructions and code tagged as [local_dev]. (Unfortunately, just before this commit explaining the tags and branches)

In principle, you could work on the [local] branch, test and once it is fixed then merge into [sync] branch and later git pull on the server. Beware that there is one hard-wired default domain name in lib/Bawi/Auth.pm that is different between [local] and [sync]. In theory this should not affect when merged, but work around would be to checkout [sync] branch, and individually merge commits by `git cherry-pick` or even `git checkout local [filename]`.

(See more on http://jasonrudolph.com/blog/2009/02/25/git-tip-how-to-merge-specific-files-from-another-branch/ )
--------------------------------------------------------------------

Once you have the code on your directory, first thing is to make configuration files from sample files.

```
cd ~/Sites/bawi-on-perl/conf
ls *.sample | awk '{print("cp "$1" "$1)}' | sed 's/.sample//2'
ls *.sample | awk '{print("cp "$1" "$1)}' | sed 's/.sample//2' | /bin/sh
```

Now we will set up the mysql databases and then correctly configure the configuration files. I assume that MySQL has been set up at the Apache2, MySQL installation section and have the root user set up.

## mysql database setup

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

Based on the MySQL database and user/password, now you can configure board.conf, main.conf, user.conf Specifically, you need to change

```
DBName bawi
DBUser bawi
DBpasswd [your MySQL password]

SessionName   bawi_session_local # something that does not interfere with other applications
SessionDomain dev.bawi.org
```

It is very important to set up the SessionDomain right. Currently I have set as dev.bawi.org (later I will add this in other settings), but if you want another name, do not forget to change the three files accordingly (board.conf, main.conf, user.conf).


## Installing necessary perl modules

The ur-old BawiX engine requires certain perl modules to be installed. Starting from El Capitan, it is almost impossible to set up system-level perl module installation via cpan. That barred many people successfully installing BawiX locally. 

For just perl scripts, we could try out Perlbrew (http://perlbrew.pl) to locally install all modules. This will effectively isolate our BawiX installation from dependency issues with OS upgrades. However, another complication is that the default mode to run locally is via mod_perl, and that effectively skips any run via perlbrew (something complicated to fix). So, we will actually change the module directory target to /usr/local/bin and run in sudo mode.

```
cpan
# setup and choose sudo mode
cpan> o conf makepl_arg "INSTALLBIN=/usr/local/bin INSTALLSCRIPT=/usr/local/bin"
cpan> o conf commit
cpan> exit
```

Now install all the necessary modules via cpan
```
cpan install HTML::Template
cpan install Text::Iconv
cpan install URI::Escape
cpan install DBI
cpan install Apache::DBI
cpan install DBD::mysql
```
--------------------------------------------

First, check whether the CGI script (without the help of mod_perl) works. For this, you need to temporarily setup environment variables:
```
export BAWI_PERL_HOME=~/Sites/bawi-on-perl
export BAWI_DATA_HOME=~/Sites/bawi-on-perl

cd ~/Sites/bawi-on-perl/main
./index.cgi
```

You should see the HTML code being outputted correctly.


### Set up the virtual hosting - 1 (installing mod_perl)

You may be tempted to try out even http://localhost/~[username]/bawi-on-perl/main/index.cgi

Unfortunately you get an internal server error. This is because the apache2 does not know the two environmental variables that we have setup in shell. There is a small snipped of perl code that has to be invoked to have the environmental variables setup. This requires configuring the apache configuration file, and let us do also setup the virtual hosting at this timepoint.

Virtual hosting is to say, instead of running it like "http://localhost/~WWolf/index.cgi" we have a virtual domain name (only used by ourselves). For convenience, I have set up dev.bawi.org. 

The code should run independent of whatever domain we are using except for a few archaic predefined URLs (which is not critical). To remedy this, there is one difference (as of now) from the sync branch to the local branch, about the defaults. By `cd ~/Sites/bawi-on-perl; grep -R dev.bawi.org .` you will easily figure out the code.

Majority of virtual hosting apache configuration is pre-written in apache2/bawi-spring configuration file. Using superuser privileges, we will link vhosts file that the apache2 configuration file is including to this file. So any configuration we need to edit the apache2/bawi-spring configuration.

Finally, although most of the Bawi code is essentially CGI program and we can interrogate the workings on shell, there is a thin wrap where mod_perl comes in, and it has to do with the apache2/bawi-spring configuration file. That is, we want to define the BAWI_PERL_HOME environment variable by using a small mod_perl snippet run every time Apache restarts. So edit of the apache2/startup.pl is also important.

So first, mod_perl has to be installed in Apache. From El Capitan, root is dished out, so we need workaround. This is the biggested change from Yosemite. 

* See: http://stackoverflow.com/questions/34240610/how-to-install-mod-perl-2-0-10-in-apache-2-4-on-os-x-el-capitan
** See *not* the accepted answer but a bit below, there is an answer for El Capitan. One important thing is missing though which I will describe below.

```
cd ~
svn checkout https://svn.apache.org/repos/asf/perl/modperl/tags/2_0_9/ mod_perl-2.0
cd mod_perl-2.0
```

Install XCode7 (in the case of El capitan). Then link the header file paths to /usr/***local***/include.

```
sudo ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/usr/include/apache2  /usr/local/include/apache2
sudo ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/usr/include/apr-1  /usr/local/include/apr-1
```

Now, fix two build codes to direct to /usr/local instead of /usr

```
sudo cp /usr/sbin/apxs /usr/local/bin # make a copy of APXS tool which Makefile.PL uses
sudo vi /usr/local/bin/apxs
```
locate the line which says:
```
my $prefix = get_vars("prefix");
```
and replace with
```
my $prefix = "/usr/local";
```

Now (this is not present in the answer from stackoverflow), you need to also fix the apr-1-config code which spits out the paths for build:

```
sudo cp /usr/bin/apr-1-config /usr/local/bin
sudo vi /usr/local/bin/apr-1-config
```

locate the line which says:
```
prefix="/usr"
```
and change to
```
prefix="/usr/local"
```

Now, ensure that /usr/local/bin is in your path before /usr/sbin/ :
```
export PATH=/usr/local/bin:$PATH
```

Now we are set to build mod_perl:
```
cd ~/mod_perl-2.0
perl Makefile.PL MP_CCOPTS=-std=gnu89; make ; sudo make install
```

Now change the apache configuration file to include mod_perl (from correct path)
```
sudo vi /etc/apache2/httpd.conf
```

On the last line with all the LoadModule specifications add:
```
LoadModule perl_module /usr/local/libexec/apache2/mod_perl.so
```

Test configuration file and re-run:
```
sudo apachectl configtest
sudo apachectl restart
```

### Set up virtual hosting - 2

Then modify httpd.conf file to include vhosts configuration.
* http://coolestguidesontheplanet.com/set-virtual-hosts-apache-mac-osx-10-10-yosemite/
* do up to "Edit the vhosts.conf file".

That is, editing httpd.conf and enabling by uncommenting this line:
```
Include /private/etc/apache2/extra/httpd-vhosts.conf
```

and this line:
```
LoadModule vhost_alias_module libexec/apache2/mod_vhost_alias.so
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

Now, El Capitan version of image magick is available by homebrew.

```
brew install ImageMagick --with-perl
# it may ask to do brew link libpng
# and it may fail due to man5 ownership which you could change by sudo chown
```

If you have previous imagemagick installation via homebrew, please uninstall and re-install with the --with-perl option.
The installation, if properly setup with "--with-perl", will give you a suggestion in running successfully Image::Magick. Check whether it works:

```
export PERL5LIB=/usr/local/lib/perl5/site_perl
perl -e "use Image::Magick; print Image::Magick->QuantumDepth"  # just for testing
```

Now, to invoke successfully Image::Magick, we have to set the environmental variable PERL5LIB. This is same as adding a line in apache2/startup.pl in mod_perl situation:
```
cd ~/Sites/bawi-on-perl/apache2
vi startup.pl
```

Then add this line:
```
$ENV{PERL5LIB} = "/usr/local/lib/perl5/site_perl";
```

Now, restart apache:
```
sudo apachectl restart
```


### Now, the empty Bawi (local) world.

Congratulations! You are now able to explore the empty barren world of bawi-on-perl.
If you want to just test the behavior of CSS, please use `http://dev.bawi.org/board/addboard.cgi` to make a board for yourself and subscribe.

### Exploration of CSS skins etc.

The basic structure of bawi-on-perl is simple. Just as a quick guide, there are three different skins themes, but the major ones you may care is in `board/skin/` directory. For HTML templates, they are in `board/templates/`. Once you edit the templates and test CSS, and check on the web you will adapt fairly easy how things are working.

Thanks for following this road to make Bawi a better place.


-- WWolf



