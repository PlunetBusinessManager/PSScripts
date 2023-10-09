###############
# Config      #
###############

$mypassword = "" # Passwort hier eintragen!


###############
# Main Script #
###############

function Add-Encryption($cleartext)
{ 
        $crypt = ConvertTo-SecureString -String $cleartext -AsPlainText -Force
        return $crypt | ConvertFrom-SecureString
}


Add-Encryption -cleartext $mypassword
