$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot '..\scripts\CodexGear.psm1'
Import-Module $module -Force

$cases = @(
    @{ Name = 'low'; Text = 'rename one label in the README'; Profile = 'fast'; Model = 'gpt-5.6-sol'; Effort = 'low' },
    @{ Name = 'medium'; Text = 'add a contact form to the page'; Profile = 'balanced'; Model = 'gpt-6-astra'; Effort = 'low' },
    @{ Name = 'high'; Text = 'debug the failing test suite'; Profile = 'deep'; Model = 'gpt-6-astra'; Effort = 'high' },
    @{ Name = 'extra-high'; Text = 'design authentication and billing architecture for production'; Profile = 'max'; Model = 'gpt-6-astra'; Effort = 'ultra' }
)

foreach ($case in $cases) {
    $profile = Select-CodexGear -Text $case.Text
    if ($profile -ne $case.Profile) { throw "$($case.Name): expected profile $($case.Profile), got $profile" }
    $gear = Get-CodexGear -Profile $profile
    if ($gear.Model -ne $case.Model -or $gear.Effort -ne $case.Effort) {
        throw "$($case.Name): expected $($case.Model)/$($case.Effort), got $($gear.Model)/$($gear.Effort)"
    }
    [pscustomobject]@{ Name = $case.Name; Profile = $profile; Model = $gear.Model; Effort = $gear.Effort; ServiceTier = $gear.ServiceTier }
}
