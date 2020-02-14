Param
(
    [string] $appName        = "",
    [string] $appDescription = "$((Get-Content "./app/app.json" -ErrorAction SilentlyContinue | ConvertFrom-Json).brief)",
    [string] $prefix         = "",
    [int]    $idRangesFrom   = 50100,
    [string] $appId          = "$([Guid]::NewGuid())",
    [string] $testAppId      = "$([Guid]::NewGuid())",
    [string] $publisher      = "$((Get-Content "./app/app.json" -ErrorAction SilentlyContinue | ConvertFrom-Json).publisher)",
    [string] $version        = "1.0.0.0",
    [string] $projectFolder  = ".",
    [string] $appFolder      = "app",
    [string] $testAppFolder  = "test",
    [string] $devOpsFolder   = ".devops",
    [string] $toolsFolder    = ".tools"
)

function Invoke-InitProject {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $appName,
        [Parameter(Mandatory = $true)]
        [string] $publisher,
        [string] $appDescription = "",
        [string] $prefix         = "",
        [string] $suffix         = "",
        [int]    $idRangesFrom   = 50100,
        [int]    $idRangesTo     = 50199,
        [string] $appId          = "$([Guid]::NewGuid())",
        [string] $testAppId      = "$([Guid]::NewGuid())",
        [string] $version        = "1.0.0.0",
        [string] $projectFolder  = ".",
        [string] $appFolder      = "app",
        [string] $testAppFolder  = "test",
        [string] $devOpsFolder   = ".devops",
        [string] $toolsFolder    = ".tools"
        
    )
    Begin {
        Push-Location
        Set-Location $projectFolder  
    }
    Process {
        $appJson     = (Get-ChildItem -Path "$appFolder" -Filter "app.json" -Recurse)
        $testAppJson = (Get-ChildItem -Path "$testAppFolder" -Filter "app.json" -Recurse)
        
        if ($appJson) {
            $app = (Get-Content $appJson.FullName | ConvertFrom-Json)
            $app.id          = $appId
            $app.name        = $appName
            $app.publisher   = $publisher
            $app.version     = $version
            $app.description = "$($appDescription)"
            $app.brief       = "$($appDescription)"
            
            $app.idRanges[0].from = $idRangesFrom
            $app.idRanges[0].to   = $idRangesTo - 10

            $app | ConvertTo-Json -Depth 50 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content $appJson.FullName
        }

        if ($testAppJson) {
            $testApp = (Get-Content $testAppJson.FullName | ConvertFrom-Json)
            $testApp.id          = $testAppId
            $testApp.name        = "$($appName)-Tests"
            $testApp.description = "$appName | Tests"
            $testApp.brief       = "$appName | Tests"
            $testApp.publisher   = $publisher
            $testApp.version     = $version       
            $testApp.dependencies[0].appId     = $app.id
            $testApp.dependencies[0].name      = $app.name
            $testApp.dependencies[0].publisher = $app.publisher
            $testApp.dependencies[0].version   = $app.version

            $testApp.idRanges[0].from = $idRangesTo - 10
            $testApp.idRanges[0].to   = $idRangesTo

            $testApp | ConvertTo-Json -Depth 50 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content $testAppJson.FullName
        }
    
        # Create Workspace for needed folders
        $items = @{".devops" = $devOpsFolder; "app" = $appFolder; "test" = $testAppFolder }
        $folders   = @()
        $items.Keys | ? {Test-Path (Join-Path $projectFolder $items[$_])} | Sort-Object | ForEach-Object {
            $folder = @{}
            $folder.name = $_
            $folder.path = $items[$_]
            $folders += $folder
        }

        $settings  = ('{"al.codeAnalyzers":["${PerTenantExtensionCop}","${CodeCop}","${UICop}"],"CRS.AlSubFolderName":"src","CRS.ExtensionObjectNamePattern":"","CRS.FileNamePattern":"<ObjectNameShort>.al","CRS.FileNamePatternExtensions":"Ext.<ObjectNameShort>.al","CRS.FileNamePatternPageCustomizations":"PageCust.<ObjectNameShort>.al","CRS.ObjectNamePrefix":"CCO","CRS.ObjectNameSuffix":"","CRS.RemovePrefixFromFilename":true,"al.enableCodeActions":true,"CRS.RenameWithGit":true,"al.editorServicesLogLevel":"Verbose"}' | ConvertFrom-Json)
        $workspace = ('{"folders":[],"settings":{}}' | ConvertFrom-Json)
        $settings."CRS.ObjectNamePrefix" = $prefix
        $settings."CRS.ObjectNameSuffix" = $suffix
        $workspace.folders  = $folders
        $workspace.settings = $settings
        $workspace | ConvertTo-Json | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content (Join-Path $projectFolder "$appName.code-workspace") -Force -ErrorAction SilentlyContinue

        $readmeFile = (Join-Path $projectFolder "readme.md")
        if (! (Test-Path $readmeFile) -and (Test-Path (Join-Path $projectFolder "$toolsFolder/readme.template.md")) ) {
            $readme = Get-Content (Join-Path $projectFolder "$toolsFolder/readme.template.md" )
            
            "# $appName"      | Set-Content -Path $readmeFile
            ""                | Add-Content -Path $readmeFile
            "$appDescription" | Add-Content -Path $readmeFile
            ""                | Add-Content -Path $readmeFile
            $readme           | Add-Content -Path $readmeFile            
        }
        
    }
    End {
        Pop-Location
    }
}

function Get-Input {
    [CmdletBinding()]
    Param
    (
        [string] $name,
        [string] $defaultValue,
        [switch] $mandatory
    )

    $val = (Read-Host "$name (Default: '$defaultValue' [ENTER])")
    if ("$val" -eq "") {
        $val = $defaultValue
    }
    if ($mandatory -and "$val" -eq "") {
        Write-Host "$name not specified." -f red
        exit
    }
    return $val
}

# Request all parameters
$appName        = (Get-Input -name "App name"        -defaultValue $appName        -mandatory)
$publisher      = (Get-Input -name "Publisher name"  -defaultValue $publisher      -mandatory)
$appDescription = (Get-Input -name "App description" -defaultValue $appDescription)
$prefix         = (Get-Input -name "Name prefix for objects" -defaultValue $prefix)
$idRangesFrom   = [int](Get-Input -name "Id range from"      -defaultValue $idRangesFrom)
$idRangesTo     = [int](Get-Input -name "Id range to"        -defaultValue ($idRangesFrom + 99))

Invoke-InitProject `
    -appName        $appName `
    -appDescription $appDescription `
    -appId          $appId `
    -idRangesFrom   $idRangesFrom `
    -idRangesTo     $idRangesTo `
    -prefix         $prefix `
    -testAppId      $testAppId `
    -publisher      $publisher `
    -version        $version `
    -projectFolder  $projectFolder `
    -appFolder      $appFolder `
    -testAppFolder  $testAppFolder

code $projectFolder