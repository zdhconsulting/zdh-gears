$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot '..\scripts\CodexGear.psm1'
Import-Module $module -Force

$cases = @(
    @{ Name = 'low'; Text = 'rename one label in the README'; Profile = 'fast'; Model = 'gpt-5.6-sol'; Effort = 'low' },
    @{ Name = 'medium'; Text = 'add a contact form to the page'; Profile = 'balanced'; Model = 'gpt-6-astra'; Effort = 'low' },
    @{ Name = 'high'; Text = 'debug the failing test suite'; Profile = 'deep'; Model = 'gpt-6-astra'; Effort = 'high' },
    @{ Name = 'extra-high'; Text = 'design authentication and billing architecture for production'; Profile = 'max'; Model = 'gpt-6-astra'; Effort = 'ultra' },
    @{ Name = 'destructive deletion'; Text = 'delete the customer records'; Profile = 'max' },
    @{ Name = 'distributed consensus'; Text = 'implement a distributed consensus algorithm'; Profile = 'max' },
    @{ Name = 'cosmetic auth mention'; Text = 'rename the authentication heading in README'; Profile = 'fast' },
    @{ Name = 'bare auth mention'; Text = 'authentication'; Profile = 'balanced' },
    @{ Name = 'unknown'; Text = 'frobnicate the widget'; Profile = 'balanced' },
    @{ Name = 'underspecified'; Text = 'quick'; Profile = 'balanced' },
    @{ Name = 'whitespace only'; Text = '   '; Profile = 'balanced' },
    @{ Name = 'leading dashes unknown'; Text = '--unrecognized'; Profile = 'balanced' },
    @{ Name = 'leading dashes risk'; Text = '--low delete the customer records'; Profile = 'max' },
    @{ Name = 'low wording cannot cancel risk'; Text = 'quick simple low gear fix for authentication'; Profile = 'max' },
    @{ Name = 'deletion review risk'; Text = 'code review: delete the customer records'; Profile = 'max' },
    @{ Name = 'auth review risk'; Text = 'review the authentication changes'; Profile = 'max' },
    @{ Name = 'ordinary review'; Text = 'review the code'; Profile = 'review' },
    @{ Name = 'cosmetic plus auth work'; Text = 'rename the authentication heading in README and implement OAuth'; Profile = 'max' },
    @{ Name = 'cosmetic plus deletion'; Text = 'rename one label; delete the customer records'; Profile = 'max' },
    @{ Name = 'cosmetic plus debug'; Text = 'rename one label and debug the failing tests'; Profile = 'deep' },
    @{ Name = 'auth fix mentioning a label'; Text = 'fix authentication code with a new label'; Profile = 'max' },
    @{ Name = 'auth flaw mentioning a label'; Text = 'fix the authentication flaw by changing the label'; Profile = 'max' },
    @{ Name = 'remove data'; Text = 'remove obsolete customer records'; Profile = 'max' },
    @{ Name = 'status'; Text = 'show git status'; Profile = 'fast' },
    @{ Name = 'boost mode'; Text = 'boost mode'; Profile = 'boost'; Model = 'gpt-6-astra'; Effort = 'ultra' },
    @{ Name = 'boost mode simple task'; Text = 'boost mode: rename one label'; Profile = 'boost' },
    @{ Name = 'save tokens mode'; Text = 'save tokens mode'; Profile = 'saver'; Model = 'gpt-5.3-codex-spark'; Effort = 'low' },
    @{ Name = 'save tokens simple task'; Text = 'save tokens mode: rename the authentication heading in README'; Profile = 'saver' },
    @{ Name = 'save tokens risk precedence'; Text = 'save tokens mode: delete the customer records'; Profile = 'max' },
    @{ Name = 'save tokens debug precedence'; Text = 'save tokens mode: debug failing tests'; Profile = 'deep' },
    @{ Name = 'save tokens implementation precedence'; Text = 'save tokens mode: add a contact form'; Profile = 'balanced' },
    @{ Name = 'normalized whitespace'; Text = "rename  the AUTHENTICATION`nheading in README"; Profile = 'fast' }
)

foreach ($case in $cases) {
    $profile = Select-CodexGear -Text $case.Text
    if ($profile -ne $case.Profile) { throw "$($case.Name): expected profile $($case.Profile), got $profile" }
    $gear = Get-CodexGear -Profile $profile
    if ($case.ContainsKey('Model') -and ($gear.Model -ne $case.Model -or $gear.Effort -ne $case.Effort)) {
        throw "$($case.Name): expected $($case.Model)/$($case.Effort), got $($gear.Model)/$($gear.Effort)"
    }
    [pscustomobject]@{ Name = $case.Name; Profile = $profile; Model = $gear.Model; Effort = $gear.Effort; ServiceTier = $gear.ServiceTier }
}

foreach ($aliasCase in @(
    @{ Alias = 'boost'; Target = 'max' },
    @{ Alias = 'saver'; Target = 'saver' },
    @{ Alias = 'save-tokens'; Target = 'saver' }
)) {
    $aliasGear = Get-CodexGear -Profile $aliasCase.Alias
    $targetGear = Get-CodexGear -Profile $aliasCase.Target
    if ($aliasGear.Profile -ne $aliasCase.Alias) { throw 'Alias must retain its selected profile name.' }
    foreach ($property in @('Gear', 'Model', 'Effort', 'ServiceTier', 'Command')) {
        if ($aliasGear.$property -ne $targetGear.$property) { throw "$($aliasCase.Alias): $property differs from $($aliasCase.Target)." }
    }
}

