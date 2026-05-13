if ($env:RELEASE_TAG) {
  $tag = $env:RELEASE_TAG
} else {
  $tag = git describe --tags --abbrev=0 2>$null
  if (-not $tag) {
    $tag = 'v0.0.1'
  }
}

"TAG=$tag" >> $env:GITHUB_ENV
"Tag: $tag"
