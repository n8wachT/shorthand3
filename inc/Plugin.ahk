/*
	1. plugin.ahk gets included from the main script
	2. plugin.ahk looks at the plugin folder and notes which plugins are there and what their modified timestamp is
	3. plugin.ahk compares the list of plugins and their timestamps to a previous list from the ini file
	4. 	a)	if the list is the same, assume all the plugins check out, so run the files (using plugin_loader.ahk)
		b)	if the list is NOT the same, plugin.ahk checks all different plugins with plugin_tester.ahk
*/

Plugins:
	FileDelete %A_ScriptDir%\plugin_list.ahk	; this file will contain the #include lines for plugin_loader, to be appended by this label
	; first we need to see if there are new or modified scripts
	; so, 1) check the names of the plugins and timestamps of the plugins
	Loop, %plugin_folder%\*.ahk
	{
		FileGetTime, LastModified, %A_LoopFileLongPath%
		FileName := SubStr(A_LoopFileName, 1, -1 - StrLen(A_LoopFileExt))
		if A_Index = 1
		{
			plugins_active_new = %A_LoopFileName%|%LastModified%
			plugins_LoadList = %FileName%
			plugins_IncList = #include *i %A_LoopFileLongPath%
		}
		else
		{
			plugins_active_new = %plugins_active_new%,%A_LoopFileName%|%LastModified%
			plugins_LoadList = %FileName%|%plugins_LoadList%
			plugins_IncList = #include *i %A_LoopFileLongPath%`n%plugins_IncList%
		}
	}
	; now, collect the previously checked variable from the ini file
	IniRead, plugins_active_old, %ini_file%, Plugins, List,
	; 2) see if there was any new plugin or modified plugin
	if ( plugins_active_old <> plugins_active_new	) ; this means there was a change
	{
		f_dbgoutput(gen,dbg,A_LineNumber,3,A_ThisLabel " new or modified plugins found")
		if plugins_active_old = ""
		{
			; there was no previously checked variable, so check all plugins
			Loop, %A_ScriptDir%\Plugins\*.ahk
				runwait, "%A_AhkPath%" "%A_ScriptDir%\app\plugin_tester.ahk" "%A_LoopFileLongPath%" "%A_ScriptDir%\plugins\disabled\"
		}
		else
		{
			; see which plugin was changed and just check that plugin
			loop, parse, plugins_active_new, `,
			{
				if A_LoopField not in %plugins_active_old%
				{
					outputdebug %A_LoopField% changed: checking
					StringLeft, OutputVar, A_LoopField, % InStr(A_LoopField, "|") - 1	; gets the filename
					runwait, "%A_AhkPath%" "%A_ScriptDir%\app\plugin_tester.ahk" "%A_ScriptDir%\Plugins\%OutputVar%" "%A_ScriptDir%\plugins\disabled\"
				}
				else
					outputdebug %A_LoopField% unchanged: checking next plugin
			}
		}
		; now all the faulty plugins have been moved, so do another inventory and write that to the ini_file
		Loop, %plugin_folder%\*.ahk
		{
			FileGetTime, LastModified, %A_LoopFileLongPath%
			FileName := SubStr(A_LoopFileName, 1, -1 - StrLen(A_LoopFileExt))
			if A_Index = 1
			{
				plugins_active_new = %A_LoopFileName%|%LastModified%
				plugins_LoadList = %FileName%
				plugins_IncList = #include *i %A_LoopFileLongPath%
			}
			else
			{
				plugins_active_new = %plugins_active_new%,%A_LoopFileName%|%LastModified%
				plugins_LoadList = %plugins_LoadList%|%FileName%
				plugins_IncList = #include *i %A_LoopFileLongPath%`n%plugins_IncList%
			}
		}
		IniWrite, %plugins_active_new%, %ini_file%, Plugins, List
	}
	FileAppend, %plugins_IncList%, %A_ScriptDir%\plugin_list.ahk	; prepare the includelist for plugin_loader.ahk
	IniWrite, %plugins_LoadList%, %ini_file%, Plugins, LoadList
	; the plugins have either not been changed since last check, or have been rechecked
	Run, "%plugin_loader%" "%ini_file%", %A_ScriptDir%, Min, PluginLoaderPID
	f_dbgoutput(gen,dbg,A_LineNumber,3,A_ThisLabel " no new plugins found")
return