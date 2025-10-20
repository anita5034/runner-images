using module ../SoftwareReport.Nodes.psm1

BeforeDiscovery {
    Import-Module $(Join-Path $PSScriptRoot "TestHelpers.psm1") -DisableNameChecking
}

Describe "Sanity.UnitTests" {
    Context "Basic checks" {
        It "Arithmetic 1+1 equals 2" {
            (1 + 1) | Should -Be 2
        }

        It "ShouldBeArray helper validates arrays" {
            $actual = @('a', 'b', 'c')
            $expected = @('a', 'b', 'c')
            $actual | Should -BeArray $expected
        }
    }
}
