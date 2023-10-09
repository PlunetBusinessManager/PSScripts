#Requires -RunAsAdministrator

using namespace System.IO
using namespace System.Collections
using namespace System.Security.Cryptography.X509Certificates
using module ADFS
#------------------------------------------------------------------------------------------------------------
# Cmdlet for configuring Plunet SAML on an AD FS IDP
# Author: Alexander Schüßler
#-------------------------------------------------------------------------------------------------------------


function Create-PlunetIDPEntry
{
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$true)]
    [Alias("Name")]
    [String]$relyingPartyTrustName,
    [Parameter(Position=1,mandatory=$true)]
    [Alias("Uri", "PlunetBaseURL")]
    [String]$serviceProviderBaseURL,
    [Parameter(Position=2,mandatory=$false)]
    [Alias("Notes")]
    [String]$trustPolicyNotes ="",
    [Parameter(Position=3,mandatory=$false)]
    [String]$encryptionCertPath,
    [Parameter(Position=4,mandatory=$false)]
    [String]$signatureCertPath
    )


    begin
    {
        #----------------------------------------------------------
        # Checking cert paths
        #----------------------------------------------------------
        if($encryptionCertPath.Length -gt 0){  #because it's optional....
            if(-Not (Test-Path $encryptionCertPath) -or [FileInfo]::new($encryptionCertPath).Extension -notin (".cer", ".crt")){
                Write-Error "Encryption Certificate not found or in wrong format. Script terminated!"
                exit
            }
            else
            {
                $encryptionCert = [X509Certificate2]::CreateFromCertFile($encryptionCertPath)
            }
        }


        if($signatureCertPath.Length -gt 0){  #because it's optional....
            if(-Not (Test-Path $signatureCertPath) -or [FileInfo]::new($signatureCertPath).Extension -notin (".cer", ".crt")){
                Write-Error "Signature Certificate not found or in wrong format. Script terminated!"
                exit
            }
            else
            {
                $signatureCert = [X509Certificate2]::CreateFromCertFile($signatureCertPath)
            }

        }

    }
          
    process
    {
        #----------------------------------------------------------
        # Compose SAML Endpoints
        #----------------------------------------------------------
        #region SAML Endpoints
        $SAMLEndpoints = [ArrayList]::new()
        [void]$SAMLEndpoints.Add((New-AdfsSamlEndpoint -Uri "$($serviceProviderBaseURL)/saml-res" -Binding Artifact -Protocol SAMLAssertionConsumer -Index 0))
        [void]$SAMLEndpoints.Add((New-AdfsSamlEndpoint -Uri "$($serviceProviderBaseURL)/saml-res" -Binding POST -Protocol SAMLAssertionConsumer -Index 1))
        [void]$SAMLEndpoints.Add((New-AdfsSamlEndpoint -Uri "$($serviceProviderBaseURL)/saml-res" -Binding Redirect -Protocol SAMLAssertionConsumer -Index 2))
        [void]$SAMLEndpoints.Add((New-AdfsSamlEndpoint -Uri "$($serviceProviderBaseURL)/saml-idp" -Binding Artifact -Protocol SAMLAssertionConsumer -Index 3))
        [void]$SAMLEndpoints.Add((New-AdfsSamlEndpoint -Uri "$($serviceProviderBaseURL)/saml-idp" -Binding POST -Protocol SAMLAssertionConsumer -Index 4))
        [void]$SAMLEndpoints.Add((New-AdfsSamlEndpoint -Uri "$($serviceProviderBaseURL)/saml-idp" -Binding Redirect -Protocol SAMLAssertionConsumer -Index 5))
        #endregion

        #----------------------------------------------------------
        # Define Claim Iussance Policy
        #----------------------------------------------------------
        $transformRules= @'

        @RuleName = "LDAP User Mapping"
        c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
         => issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn", "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"), query = ";mail,userPrincipalName,sAMAccountName,tokenGroups(SID),givenName,sn;{0}", param = c.Value);

        @RuleName = "E-Mail Transform"
        c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"]
         => issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = c.Value, ValueType = c.ValueType, Properties["http://schemas.xmlsoap.org/ws/2005/05/identity/claimproperties/format"] = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress");

        @RuleName = "LDAP Group Mapping"
        c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-1656038718-537755943-1671300986-1309", Issuer == "AD AUTHORITY"]
         => issue(Type = "Group", Value = "group", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, ValueType = c.ValueType);
'@
        #----------------------------------------------------------
        # Compiling information for new Relying Party Trust
        #----------------------------------------------------------
        $SAMLIdentifier = "$($serviceProviderBaseURL)/saml"        
        $accessControlPolicy = "Permit everyone"
        $relyingPartyTrustParams = @{
            Name = $relyingPartyTrustName
            Identifier = $SAMLIdentifier
            Enabled = $true
            SamlEndpoint = $SAMLEndpoints
            IssuanceTransformRules = $transformRules
            AccessControlPolicyName = $accessControlPolicy
        }

        if($encryptionCert -is [X509Certificate])
        {
            $relyingPartyTrustParams.EncryptionCertificate = $encryptionCert
        }

        if($signatureCert -is [X509Certificate])
        {
            $relyingPartyTrustParams.RequestSigningCertificate = $signatureCert
        }
        if($trustPolicyNotes.Length -gt 0)
        {
            $relyingPartyTrustParams.Notes = $trustPolicyNotes
        }
       
        try{

            #----------------------------------------------------------
            # Do the actual magic!
            #----------------------------------------------------------
            Add-AdfsRelyingPartyTrust @relyingPartyTrustParams

        }
        catch{

            Write-Error "Could not create Relying party Trust for Plunet. An error occured:"
            Write-Error $_
        }
    }
}
