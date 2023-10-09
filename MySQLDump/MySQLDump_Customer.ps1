###############
# Config      #
###############

#Add Password Hash here
$password = "" 
#Path to MySQL Bin Directory - Default: C:\Program Files\MySQL\MySQL Server 5.7\bin
$mysqlpath = "C:\Program Files\MySQL\MySQL Server 5.7\bin" 
#Database user to be used for authentication - Default: root
$mysqluser = "root" 
#Name of database to be backupped - Default: plunet
$dbname = "plunet" 
#Host name of MySQL Server - Default: localhost
$dbhost = "localhost"
#Listener port for MySQL Server - Default: 3306
$dbport = 3306
#Target path for dumps
$backuppath = "C:\PlunetDB\dbbackup\dumps" 
#Can also use a remote path instead
#$backuppath = \\backupserver\plunetbackup\dumps" 
#Rotation - set this to $true, if you like to have a "weekday" backup that will be overwritten 
#every week, i.e. you always have the last 7 days as backup
$optionRotation = $false 

###############
# Main Script #
###############

function Remove-Encryption ($crypt)
{
    $decrypt = ConvertTo-SecureString $crypt
    $bytereference = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($decrypt)
    $finalbytes = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bytereference)
        
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bytereference)

    return $finalbytes
}

$finalbytes = Remove-Encryption $password

if(-not (Test-Path $mysqlpath))
{
    return
}

if(-not (Test-path $backuppath))
{
    try
    {
        New-item -Path $backuppath -ItemType Directory -Force

    }

    catch
    {

        return
    }
}


if($backuppath -like "\\*" -or $backuppath -like "//*")
{
    $doremotebackup = $true
}

if($doremotebackup)
{
    $realbackuppath = "C:\Windows\temp\"
}
else
{
    $realbackuppath = $backuppath
}

Set-Location $mysqlpath

if($optionRotation)
{
    $weekDays = (Get-Culture).DateTimeFormat.DayNames
    $weekDay = $weekDays[($(Get-date).DayOfWeek.value__)]
    $filename = "$($realbackuppath)\$($dbname)-$($weekDay)-backup.sql"
}
else
{
    $filename = "$($realbackuppath)\$(Get-Date -Format "yy-MM-dd")$($dbname)-backup.sql"
}


$cmd = "mysqldump.exe --single-transaction -u $($mysqluser) -p$($finalbytes) -h $($dbhost) -P $($dbport) $($dbname) > $($filename)"


cmd /c $cmd

if($doremotebackup)
{
    Move-Item -Path $filename -Destination $backuppath -Force

}
