#! /bin/bash

home_dir=/home/backup_user
user='backup_user'
web_user='www-data'
s3_bucket='nextcloudbackups'
nextcloud_dir=/var/www/html/
data_dir=/data/
backup_dir=$home_dir/backups
DB_archive_pass=$(openssl rand -base64 24)
full_backup_pass=$(openssl rand -base64 24)
timestamp=$(date +"%d.%m.%y")
day_of_week=$(date '+%w')
day_of_month=$(date '+%d')
DB_pass=$(</$home_dir/sql.pass) # Make sure the file is read only by backup_user (chmod 400)
GPG_pass=$(</$home_dir/gpg.pass) # Make sure the file is read only by backup_user (chmod 400)
panic_file=$home_dir/nextcloud_backup.panic
Email_Address='hello@chrisappleyard.net'
Encrypted_Message=$home_dir/message.asc

# Check if running as root.

if [ "$(id -u)" != "0" ]; then
                echo "This script must be run as root" 1>&2
                        exit 1
fi

sudo -u $web_user php $nextcloud_dir/occ maintenance:mode --on

# The first step is to backup the Database for Nextcloud.

# Firstly, we need to take a copy of the entire DB.
mysqldump --single-transaction -h localhost -u NxtCldDB -p$DB_pass nextcloud > $backup_dir/nextcloud-sqlbkp_$timestamp.bak

# Then we need to use 7-zip to create an encrypted archive using a random generated password.
7za a -p$DB_archive_pass $backup_dir/DB_Backup_$timestamp.zip $backup_dir

# Send the DB password over via email using PGP Encryption.
echo $DB_archive_pass | sudo -u $user gpg --pinentry-mode loopback --passphrase-file $home_dir/gpg.pass --encrypt --sign --armor -r $Email_Address --output $Encrypted_Message
cat $Encrypted_Message | sudo -u $user mail -s "Latest DB Archive Pass" $Email_Address
rm -f $Encrypted_Message

# Delete old DB backups every week on a Sunday

if [ $day_of_week -eq 0 ]; then

	sudo -u $user s3cmd del s3://$s3_bucket/DB_Backups/* --human-readable-sizes --ssl
fi

# Now we need to upload the encrypted DB archive to the S3 Bucket.
sudo -u $user s3cmd put -p $backup_dir/DB_Backup_$timestamp.zip s3://$s3_bucket/DB_Backups/ --human-readable-sizes --ssl

# On a Sunday only, we need to take a full backup of the Nextcloud files and Data files (we exclude the DB backup, as it has already been uploaded)
if [ $day_of_week -eq 0 ]; then

		# Take copies of the Nextcloud files and data files
        cp -rp $nextcloud_dir $backup_dir/full_backup/html
        cp -rp $data_dir $backup_dir/full_backup/data

        # Create a password protected archive of the full_backup directory
        7za a -p$full_backup_pass /$backup_dir/Full_Backup_$timestamp.zip $backup_dir/full_backup/
        
        # Send the password to myself using PGP encryption
        echo $full_backup_pass | sudo -u $user gpg --pinentry-mode loopback --passphrase-file $home_dir/gpg.pass --encrypt --sign --armor -r $Email_Address --output $Encrypted_Message
        cat $Encrypted_Message | sudo -u $user mail -s "Latest Full Backup Pass" $Email_Address
        rm -f $Encrypted_Message
        
        # Delete the old archive from last week.
        sudo -u $user s3cmd del s3://$s3_bucket/Full_Backup/* --human-readable-sizes --ssl

        # Fith, we upload the new archive.
        sudo -u $user s3cmd put -p $backup_dir/Full_Backup_$timestamp.zip s3://$s3_bucket/Full_Backup/ --human-readable-sizes --ssl

        #Delete the files locally
        rm -rf $backup_dir/full_backup/html/*
		rm -rf $backup_dir/full_backup/data/*
		find $backup_dir/full_backup -maxdepth 1 -type f -exec rm -f {} \;
    fi

# We can now delete anything in the Backup Dir.
find $backup_dir -maxdepth 1 -type f -exec rm -f {} \;

# Delete files that have been removed locally from the remote location while doing a sync every 1st of the month.
# Have to run as root, then specify the config file, as the nextcloud config won't get backed up.
if [ $day_of_month -eq 1 ]; then

	sudo s3cmd -e sync $nextcloud_dir s3://$s3_bucket/Nextcloud_Backups/ --delete-removed --human-readable-sizes --ssl --config=$home_dir/.s3cfg
	sudo s3cmd -e sync $data_dir s3://$s3_bucket/Data_Backups/ --delete-removed --human-readable-sizes --ssl --config=$home_dir/.s3cfg
else

	sudo s3cmd -e sync $nextcloud_dir s3://$s3_bucket/Nextcloud_Backups/ --human-readable-sizes --ssl --config=$home_dir/.s3cfg
	sudo s3cmd -e sync $data_dir s3://$s3_bucket/Data_Backups/ --human-readable-sizes --ssl --config=$home_dir/.s3cfg
fi

if test -s $panic_file; then

    	# If the file exists and is not empty, encrypt the panic file and send over email with PGP encryption.
    	sudo -u $user gpg --pinentry-mode loopback --passphrase-file $home_dir/gpg.pass --encrypt --sign --armor -r $Email_Address $panic_file
        rm -rf $panic_file
        cat $home_dir/nextcloud_backup.panic.asc | sudo -u $user mail -s "Nextcloud Backup: PANIC" $Email_Address 
        rm -rf $home_dir/nextcloud_backup.panic.asc
else
    
    # If the file is empty, delete it.
    rm -rf $panic_file
fi

# Turn off Nextcloud maintenance mode.
sudo -u $web_user php $nextcloud_dir/occ maintenance:mode --off