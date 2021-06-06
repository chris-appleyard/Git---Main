Nextcloud Secure Backups

Purpose:

This script will help you automate backups of your Nextcloud Instance by backing up modified files daily (s3cmd sync) and doing a full backup weekly (s3cmd put)

This will backup your Nextcloud web files, data directory and your Database.

Prerequisites:

A Nextcloud installation that uses Apache2 and a MySQL/MariaDB Database
Unprivileged user account for backups
p7zip-full
python3
python3-pip
s3cmd
OpenSSL
Mailutils
Postfix
S3 compatible bucket (I recommend Exoscale if you are in Europe)
GNUPG (Used for PGP emails, for Panic file and daily backup passwords)

Instructions to setup the script:

- Create a new user account for backups
    sudo adduser backup_user

- Install s3cmd
    sudo apt-get install python3-pip -y
    sudo pip3 install s3cmd

- Configure s3cmd for the backup user
    su - backup_user
    s3cmd --configure

- Install GNUPG
    sudo apt install gnupg -y

- Setup GNUPU
    sudo usermod -aG sudo backup_user
    su – backup_user
    sudo chown backup_user /dev/pts/0
    ls -l $(tty)
    gpg --gen-key 
    # Create the PGP keys for the backup user, this will ask you to create a passphrase, create a strong one and save it somewhere safe.
    # Then, grab a copy of your PGP public key and put it into a text file, ready for import
    gpg --import <your_email_address>.asc
    gpg --sign-key <your_email_address>
    gpg –list-keys
    rm -rf <your_email_address>.asc
    gpg --output ~/mygpg.key --armor --export backup_user
    # Export the PGP Public Key
    cat mygpg.key 
    # Save this public key within your contacts on your email account
    sudo chown <your_privileged_user> /dev/pts/0
    ls -l $(tty)
    exit
    sudo gpasswd -d backup_user sudo

- Disable Login's for the backup user
    sudo vi /etc/passwd
    <..............................>:/home/backup_user:/usr/sbin/nologin

- Save the GPG passphrase as a read only file
    sudo -u backup_user vi /home/backup_user/gpg.pass
    sudo -u backup_user chmod 400 /home/backup_user/gpg.pass

- Save the Nextcloud Database passphrase as a read only file
    sudo -u backup_user vi /home/backup_user/sql.pass
    sudo -u backup_user chmod 400 /home/backup_user/sql.pass

- Install 7-Zip
    sudo apt install p7zip-full -y

- Save the backup script within the backup user's Home Dir
    sudo -u backup_user nano /home/backup_user/backup.sh
    # copy the script contents in this file
    # make it executable
    sudo -u backup_user chmod 700 /home/backup_user/backup.sh

- Create a Cron job for this
    sudo vi /etc/cron.d/nextcloud_backup
    0 4 * * * root /home/backup_user/backup.sh >> /var/log/nextcloud_backup.log 2>> /home/backup_user/nextcloud_backup.panic

- Create the Backup Directories
    sudo -u backup_user mkdir /home/backup_user/backups
    sudo -u backup_user mkdir /home/backup_user/backups/full_backup
    sudo -u backup_user mkdir /home/backup_user/backups/full_backup/data
    sudo -u backup_user mkdir /home/backup_user/backups/full_backup/html