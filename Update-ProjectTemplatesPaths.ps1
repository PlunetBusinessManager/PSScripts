#------------------------------------------------------------------------------------------------------------
# Cmdlet and script for updating TM and Project paths in Trados Project templates (e.g. Plunet migrations).
# Author: Alexander Schüßler
#-------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------
# Config
#----------------------------------------------------------
$PlunetbasePath =""
$pathold = ""
$pathnew = ""


#----------------------------------------------------------
# Helper Function
#----------------------------------------------------------

function Update-ProjectTemplatesPaths($file, $pathold, $pathnew)
{

    [xml]$xml = Get-Content $file

    #---------------------------
    # Translation Memories
    #---------------------------
    $foundnodes = Select-Xml -Xml $xml -XPath "//MainTranslationProviderItem"

    foreach ($node in $foundnodes)
    {
        $tmpath = $node.Node.Attributes["Uri"].Value
        $node.Node.Attributes["Uri"].Value = $tmpath.Replace($pathold, $pathnew)
    }
    
    #---------------------------
    # Project locations
    #---------------------------
    
    $foundnodes = Select-Xml -Xml $xml -XPath "//SettingsBundle/SettingsGroup/Setting"
    foreach ($node in $foundnodes)
    {
        $nodetochange =  $node.Node.Id
        if($nodetochange -ne "ProjectLocation")
        {
            continue
        }
        $node.node.innerXML = $node.node.innerXML.Replace($pathold, $pathnew)
    }


    $xml.Save([string]$file)
}




#----------------------------------------------------------
# Main Script
#----------------------------------------------------------
$Project_templates_global = Get-ChildItem "$($PlunetbasePath)\Template\project_templates" -Recurse -Include *.sdltpl
$Project_templates_customer = Get-ChildItem "$($PlunetbasePath)\customer" -Recurse -Include *.sdltpl

foreach ($projecttemplate in $Project_templates_global)
{
    Update-ProjectTemplatesPaths -file $projecttemplate -pathold $pathold -pathnew $pathnew
}

foreach ($projecttemplate in $Project_templates_customer)
{
    Update-ProjectTemplatesPaths -file $projecttemplate -pathold $pathold -pathnew $pathnew
}
