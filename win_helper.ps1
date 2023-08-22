# 0 "My service" myvalue=73 My output text which may contain spaces
##  0                                       Status                  Der Zustand des Services wird als Ziffer angegeben: 0 für OK, 1 für WARN, 2 für CRIT und 3 für UNKNOWN. Alternativ ist es möglich, den Status dynamisch berechnen zu lassen: dann wird die Ziffer durch ein P ersetzt.
## "My service"                             Service-Name            Der Name des Services, wie er in Checkmk angezeigt wird, in der Ausgabe des Checks in doppelten Anführungszeichen. Falls der Service-Name keine Leerzeichen enthält, können Sie sich die Anführungszeichen sparen.
## myvalue=73;65;75                         Wert und Metriken       Metrikwerte zu den Daten. Sie finden im Kapitel zu den Metriken näheres zum Aufbau. Alternativ können Sie ein Minuszeichen setzen, wenn der Check keine Metriken ausgibt.
## My output text which may contain spaces  Statusdetail            Details zum Status, wie sie in Checkmk angezeigt werden. Dieser Teil kann auch Leerzeichen enthalten.
##
enum cmkstatus {
    OK      = 0
    WARN    = 1
    CRIT    = 2
    UNKNOWN = 3
}

class CheckmkService {
    [cmkstatus]$State
    [string] $Service
    [string] $Detail
    [string] $MetricName
    [int] $MetricValue
    [int] $MetricWarn
    [int] $MetricCrit
    [int] $MetricMin
    [int] $MetricMax

    # Workaround costructor chaining
    hidden [void] Init ($State, $Service, $Detail) {
        $this.State    = $State
        $this.Service  = $Service
        $this.Detail   = $Detail
    }

    hidden [void] Init ($State, $Service, $Detail, $MetricName, $MetricValue) {
        $this.Init($State, $Service, $Detail)
        $this.MetricName    = $MetricName
        $this.MetricValue    = $MetricValue
    }

    hidden [void] Init ($Service, $Detail, $MetricName, $MetricValue, $MetricWarn, $MetricCrit, $MetricMin, $MetricMax) {
        $dummyState = [cmkstatus]::UNKNOWN
        $this.Init($dummyState, $Service, $Detail, $MetricName, $MetricValue)
        $this.MetricWarn    = $MetricWarn
        $this.MetricCrit    = $MetricCrit
        $this.MetricMin     = $MetricMin
        $this.MetricMax     = $MetricMax
    }

    CheckmkService($State, $Service, $Detail) {

        $this.Init($State, $Service, $Detail)
    }

    CheckmkService($State, $Service, $Detail, $MetricName, [int]$MetricValue) {

        $this.Init($State, $Service, $Detail, $MetricName, $MetricValue)
    }

    CheckmkService($Service, $Detail, $MetricName, [int]$MetricValue, [int]$MetricWarn, [int]$MetricCrit, [int]$MetricMin, [int]$MetricMax) {
        $this.Init($Service, $Detail, $MetricName, $MetricValue, $MetricWarn, $MetricCrit, $MetricMin, $MetricMax)
    }

    hidden [string]GetMetricString() {
        # metricname=value;warn;crit;min;max
        # count=73;80;90;0;100
        $metricString =  '{0}={1};{2};{3};{4};{5}' -f $this.MetricName, $this.MetricValue, $this.MetricWarn ,$this.MetricCrit ,$this.MetricMin ,$this.MetricMax
        if (-not ($this.MetricWarn)) {
            $metricString = '{0}={1}' -f $this.MetricName, $this.MetricValue
        }
        return $metricString
    }

    [string]ToString(){
        $outputString = '{0} "{1}" - {2}'
        if ($this.MetricName) { $outputString = '{0} "{1}" {3} {2}' }
        if ($this.MetricWarn) { $outputString = 'P "{1}" {3} {2}' }
        return $outputString -f $this.State.value__, $this.Service, $this.Detail, $this.GetMetricString()
    }
}

function New-CheckmkService {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'Simple')]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'NameValue')]
        # [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'NameValueMinMax')]
        [cmkstatus]$State,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'Simple')]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'NameValue')]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [string]$Service,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'Simple')]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'NameValue')]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [string]$Detail,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'NameValue')]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [string]$MetricName,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'NameValue')]
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [int]$MetricValue,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [int]$MetricWarn,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [int]$MetricCrit,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [int]$MetricMin,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory, ParameterSetName = 'StateCalculated')]
        [int]$MetricMax
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Simple") {
            [CheckmkService]::new($State, $Service, $Detail)
        }
        if ($PSCmdlet.ParameterSetName -eq "NameValue") {
            [CheckmkService]::new($State, $Service, $Detail, $MetricName, $MetricValue)
        }
        if ($PSCmdlet.ParameterSetName -eq "StateCalculated") {
            [CheckmkService]::new($Service, $Detail, $MetricName, $MetricValue, $MetricWarn, $MetricCrit, $MetricMin, $MetricMax)
        }
    }
}

function Write-CMKOutput {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Mandatory)][CheckmkService]$CheckmkService
    )

    process {
        $CheckmkService.ToString()
    }

}
