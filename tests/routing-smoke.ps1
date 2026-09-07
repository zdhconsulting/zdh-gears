#Requires -Version 7.0
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PackageRoot 'scripts/CodexGear.psm1') -Force
$expected = @{
    fast=@('low','gpt-5.6-sol','low','fast'); balanced=@('medium','gpt-6-astra','low','standard'); standard=@('medium','gpt-6-astra','low','standard')
    deep=@('high','gpt-6-astra','high','standard'); review=@('review','gpt-6-astra','high','standard'); max=@('xhigh','gpt-6-astra','ultra','standard')
    boost=@('xhigh','gpt-6-astra','ultra','fast'); saver=@('low','gpt-5.3-codex-spark','low','standard'); 'save-tokens'=@('low','gpt-5.3-codex-spark','low','standard')
    'saver-compact'=@('medium','gpt-5.6-luna','low','standard'); 'saver-work'=@('medium','gpt-5.6-sol','low','standard'); 'saver-risk'=@('high','gpt-6-astra','high','standard')
}
$cases = @(
    @('rename one label in the README','fast'), @('add a contact form to the page','balanced'), @('debug the failing test suite','deep'),
    @('design authentication and billing architecture for production','max'), @('delete the customer records','max'), @('implement a distributed consensus algorithm','max'),
    @('rename the authentication heading in README','fast'), @('authentication','balanced'), @('frobnicate the widget','balanced'), @('quick','balanced'), @('   ','balanced'),
    @('--unrecognized','balanced'), @('--low delete the customer records','max'), @('quick simple low gear fix for authentication','max'),
    @('code review: delete the customer records','max'), @('review the authentication changes','max'), @('review the code','review'),
    @('rename the authentication heading in README and implement OAuth','max'), @('rename one label; delete the customer records','max'),
    @('rename one label and debug the failing tests','deep'), @('fix authentication code with a new label','max'), @('fix the authentication flaw by changing the label','max'),
    @('remove obsolete customer records','max'), @('show git status','fast'), @('boost mode','boost'), @('boost mode: rename one label','boost'),
    @('save tokens mode','saver'), @('save tokens mode: rename the authentication heading in README','saver'), @('save tokens mode: delete the customer records','saver-risk'),
    @('save tokens mode: debug failing tests','deep'), @('save tokens mode: add a contact form','saver-compact'), @("rename  the AUTHENTICATION`nheading in README",'fast'),
    @('auto selection: rename one label in README','fast'), @('auto selection mode: rename one label','fast'), @('save tokens mode: diagnose a deadlock','saver-risk'),
    @('save tokens mode: frobnicate the widget','balanced'), @('save tokens mode: unfamiliar work','balanced'),
    @('do not use boost mode: rename one label','balanced'), @('what is boost mode?','balanced'), @('boost mode?','balanced'),
    @('explain save tokens mode','balanced'), @('turn on boost mode: show git status','boost'), @('use save tokens mode: show git status','saver'),
    @('boost  mode: rename one label','boost'), @("save tokens`tmode: rename one label",'saver'), @("auto`nselection: rename one label",'fast'),
    @('save tokens mode: debug one failing unit test','saver-work'), @('save tokens mode: fix a regression in one helper','saver-work'),
    @('save tokens mode: implement a button component','saver-compact'), @('save tokens mode: review the code','review'),
    @('save tokens mode: debug one production component','saver-risk'), @('save tokens mode: add a database migration','saver-risk'),
    @('save tokens mode: migrate one helper','saver-risk'), @('save tokens mode: implement authentication','saver-risk'),
    @('save tokens mode: design architecture for the application','saver-risk'), @('save tokens mode: debug across several files','saver-risk'),
    @('save tokens mode: add a form and implement another helper','deep'), @('save tokens mode: debug one unit test and refactor a page','deep'),
    @('save tokens mode: build an entire page','saver-risk'), @('save tokens mode: fix a bug','balanced'),
    @('auto selection: add a contact form','balanced'), @('auto selection: debug one failing unit test','deep'),
    @('boost mode: add a contact form','boost'), @('boost mode: debug one failing unit test','boost'),
    @('save tokens mode: implement a component. Rebuild the application from scratch.','saver-risk'),
    @('save tokens mode: debug one unit test. Rewrite the application.','saver-risk'),
    @('save tokens mode: add a form, rewrite the application','saver-risk'),
    @('save tokens mode: build a full application with a contact form','saver-risk'),
    @('save tokens mode: change text in multiple pages','saver-risk'), @('save tokens mode: update color in every component','saver-risk'),
    @('save tokens mode: build an application with a form','saver-risk'), @('save tokens mode: implement a component. Optimize the application.','balanced'),
    @('save tokens mode: debug one unit test. Optimize the application.','deep'),
    @('boost mode: fast fix for authentication architecture','boost'), @('fast fix for authentication architecture','max')
)
foreach ($case in $cases) {
    $profile = Select-CodexGear -Text $case[0]
    if ($profile -ne $case[1]) { throw "Route '$($case[0])': expected $($case[1]), got $profile" }
}
foreach ($name in $expected.Keys) {
    $gear = Get-CodexGear -Profile $name
    $values = $expected[$name]
    if ((@($gear.Gear,$gear.Model,$gear.Effort,$gear.ServiceTier) -join '|') -ne ($values -join '|')) { throw "Matrix mismatch: $name" }
    $argsExpected = @('-c',('model="{0}"' -f $values[1]),'-c',('model_reasoning_effort="{0}"' -f $values[2]),'-c',('service_tier="{0}"' -f $values[3]))
    $argsActual = @(New-CodexConfigArgs -Gear $gear)
    if (($argsExpected -join '|') -cne ($argsActual -join '|') -or $argsActual.Count -ne 6) { throw "Generated config mismatch: $name" }
}
foreach ($modeCase in @(@('auto','fast'),@('boost','boost'),@('save-tokens','saver'))) {
    if ((Select-CodexGear -Text 'rename one label' -Mode $modeCase[0]) -ne $modeCase[1]) { throw "Explicit -Mode failed: $($modeCase[0])" }
}
if ((Select-CodexGear -Text 'boost mode: rename one label' -Mode auto) -ne 'fast') { throw 'Explicit Auto must take precedence over text mode directive.' }
Write-Host "PASS: $($cases.Count) routing cases, $($expected.Count) complete model/effort/tier/config matrices, 4 explicit mode checks"
