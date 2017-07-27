$directory = 'themes'
$download = 'zips/{0}.zip'
$revision_file = "$directory/last-revision"

Write-Output 'Determining most recent SVN revision...'
Try{
	$svn_last_revision = ([xml](svn info --xml https://themes.svn.wordpress.org)).info.entry.revision
} Catch {
	Write-Output 'Could not determine most recent revision.'
	Break
}

Write-Output "Most recent SVN revision: $svn_last_revision"

if ( Test-Path $revision_file ) { 
	$last_revision = Get-Content $revision_file
	Write-Output "Last synced revision: $last_revision"
} else {
	$last_revision = 0
	Write-Output "You have not yet performed a successful sync. Settle in. This will take a while."
}

if ( $last_revision -ne $svn_last_revision ) {
	if ( $last_revision ) {
		$changes = ([xml](svn log --xml -v -r"$last_revision":HEAD https://themes.svn.wordpress.org)).log.logentry.paths.path|where {$_.kind -eq "dir"} | %{$_.InnerText}
		
		$matches_found = New-Object System.Collections.Generic.List[System.Object]
		$changes | % {
			if ($_ -match '^/([^/]+)') {
				$matches_found.Add($matches[1])
			}
		}
		$themes = $matches_found | select -uniq

	} else {
		$themes = ([xml](svn list --xml https://themes.svn.wordpress.org/)).lists.list.entry.name
	}
	
	
	foreach ( $theme in $themes ) {
		$theme = [System.Web.HttpUtility]::UrlDecode( $theme )
		Write-Output "Updating $theme"

		$json = Invoke-WebRequest -Uri "https://api.wordpress.org/themes/info/1.1/?action=theme_information&request[slug]=$theme" | ConvertFrom-Json
		
		$download_link = $json.download_link

		if ( ! $download_link ){
			Write-Output "Unable to fetch $theme"
			continue;
		}
		
		$outfile = $download -f $theme
	
		Invoke-WebRequest -Uri $download_link -OutFile $outfile

		if ( Test-Path $outfile ) {
			if ( Test-Path "$directory/$theme" ) {
				Remove-Item -Recurse "$directory/$theme"
			}
			Expand-Archive -Path $outfile -DestinationPath $directory
			Remove-Item $outfile
		
		} else {
			Write-Output "... download failed."
		}
	}

	Set-Content $revision_file $svn_last_revision

	if ( $? ) {
		echo "[CLEANUP] Updated $revision_file to $svn_last_revision"
	} else {
		echo "[ERROR] Could not update $revision_file to $svn_last_revision"
	}
}
