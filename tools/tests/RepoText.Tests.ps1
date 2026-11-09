#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# git stores text with LF line endings and converts it on checkout (.gitattributes). A stray CR byte makes
# git treat a file as binary, so it skips that conversion: the file then reads differently on Windows and
# on Linux CI. A regex written with a literal line break once passed on Windows and failed on Linux.

Describe 'text files in the repo' {
    It 'stores every text file with LF line endings, none as binary or mixed' {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $text = '\.(ps1|psm1|psd1|md|yml|yaml|json|cs|csproj|props|targets|slnx|xml|config|editorconfig|gitattributes|gitignore|txt|sh)$|(^|/)\.(editorconfig|gitattributes|gitignore)$|(^|/)\.githooks/[^/.]+$'

        # core.quotePath=false: otherwise git quotes a path with non-ASCII characters, and it would slip past.
        $bad = foreach ($line in git -C $root -c core.quotePath=false ls-files --eol) {
            # "i/lf    w/crlf  attr/text eol=crlf  <tab>path"
            $index, $path = ($line -split '\t', 2)
            if ($path -match $text -and $index -notmatch '^i/(lf|none)\s') { "$path ($(($index -split '\s+')[0]))" }
        }

        @($bad) | Should -BeNullOrEmpty -Because 'each should be stored as LF text; look for a stray CR byte'
    }
}
