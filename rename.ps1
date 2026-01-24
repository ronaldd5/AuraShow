$files = Get-ChildItem -Path "lib\screens\dashboard" -Recurse -Filter "*.dart"
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    if ($content) {
        $newContent = $content -replace '_SlideContent', 'SlideContent' `
                               -replace '_SlideLayer', 'SlideLayer' `
                               -replace '_SlideTemplate', 'SlideTemplate' `
                               -replace '_LayerKind', 'LayerKind' `
                               -replace '_LayerRole', 'LayerRole' `
                               -replace '_SlideMediaType', 'SlideMediaType' `
                               -replace '_TextTransform', 'TextTransform' `
                               -replace '_VerticalAlign', 'VerticalAlign' `
                               -replace '_ScrollDirection', 'ScrollDirection' `
                               -replace '_HandlePosition', 'HandlePosition'
        $newContent | Set-Content $file.FullName -NoNewline
    }
}
