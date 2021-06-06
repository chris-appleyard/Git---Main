# Nextcloud Secure Backups

# Purpose

This script will help you automate backups of your Nextcloud Instance by backing up modified files daily (s3cmd sync) and doing a full backup weekly (s3cmd put)

This will backup your Nextcloud web files, data directory and your Database.

# Prerequisites

- A Nextcloud installation that uses Apache2 and a MySQL/MariaDB Database on a Linux based OS
- Unprivileged user account for backups
- p7zip-full
- python3
- python3-pip
- s3cmd
- OpenSSL
- Mailutils
- Postfix
- S3 compatible bucket (I recommend Exoscale if you are in Europe)
- GNUPG (Used for PGP emails, for Panic file and daily backup passwords)

# Instructions to setup the script

* Create a new user account for backups
    1. sudo adduser backup_user

* Install s3cmd
    1. sudo apt-get install python3-pip -y
    2. sudo pip3 install s3cmd

* Configure s3cmd for the backup user
    1. su - backup_user
    2. s3cmd --configure

* Install GNUPG
    1. sudo apt install gnupg -y

* Setup GNUPU
    1. sudo usermod -aG sudo backup_user
    2. su – backup_user
    3. sudo chown backup_user /dev/pts/0
    4. ls -l $(tty)
    5. gpg --gen-key #Create the PGP keys for the backup user, this will ask you to create a passphrase, create a strong one and save it somewhere safe.
    6. gpg --import <your_email_address>.asc #Grab a copy of your PGP public key and put it into a text file, ready for import
    7. gpg --sign-key <your_email_address>
    8. gpg –list-keys
    9. rm -rf <your_email_address>.asc
    10. gpg --output ~/mygpg.key --armor --export backup_user #Export the PGP Public Key
    11. cat mygpg.key # Save this public key within your contacts on your email account
    12. sudo chown <your_privileged_user> /dev/pts/0
    13. ls -l $(tty)
    14. exit
    15. sudo gpasswd -d backup_user sudo

* Disable Login's for the backup user
    1. sudo vi /etc/passwd
    2. <..............................>:/home/backup_user:/usr/sbin/nologin

* Save the GPG passphrase as a read only file
    1. sudo -u backup_user vi /home/backup_user/gpg.pass
    2. sudo -u backup_user chmod 400 /home/backup_user/gpg.pass

* Save the Nextcloud Database passphrase as a read only file
    1. sudo -u backup_user vi /home/backup_user/sql.pass
    2. sudo -u backup_user chmod 400 /home/backup_user/sql.pass

* Install 7-Zip
    1. sudo apt install p7zip-full -y

* Save the backup script within the backup user's Home Dir
    1. sudo -u backup_user nano /home/backup_user/backup.sh #copy the script contents in this file
    2. sudo -u backup_user chmod 700 /home/backup_user/backup.sh #make it executable

* Create a Cron job for this
    1. sudo vi /etc/cron.d/nextcloud_backup
    2. 0 4 * * * root /home/backup_user/backup.sh >> /var/log/nextcloud_backup.log 2>> /home/backup_user/nextcloud_backup.panic

* Create the Backup Directories
   1.  sudo -u backup_user mkdir /home/backup_user/backups
   2. sudo -u backup_user mkdir /home/backup_user/backups/full_backup
   3. sudo -u backup_user mkdir /home/backup_user/backups/full_backup/data
   4. sudo -u backup_user mkdir /home/backup_user/backups/full_backup/html