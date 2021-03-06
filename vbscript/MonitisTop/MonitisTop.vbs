'Global variables
Dim cmd, agentType
Dim objHttp
Dim SupportedMonitors
Dim InternalAgents
Dim ShowMonitors
Dim ShowProcesses

'Setup dictionaries
Set Agents = CreateObject("Scripting.Dictionary")
Set SupportedMonitors = CreateObject("Scripting.Dictionary")
Set ShowMonitors = CreateObject("Scripting.Dictionary")
Set ShowProcesses = CreateObject("Scripting.Dictionary")

'Include section
Call Include("classes.vbs")
Call Include("funcString.vbs")
Call Include("funcDates.vbs")
Call Include("funcMonitisKeys.vbs")
Call Include("funcInternalAgents.vbs")
Call Include("funcExternalMonitors.vbs")
Call Include("funcFullpageMonitors.vbs")

'Initialize supported monitors. Key specifies monitor and value Item specifies monitor field to return
SupportedMonitors.Add "cpu", "user_value,%|kernel_value,%"
SupportedMonitors.Add "memory", "free_memory,MB|total_memory,MB"
SupportedMonitors.Add "drive", "result,MB"
SupportedMonitors.Add "process", "memory_usage,MB|cpu_usage,%"
SupportedMonitors.Add "http", "memUsage,MB|cpuUsage,%"
SupportedMonitors.Add "fullpage", "result, |status, "

'Command line arguments
argCmd = WScript.Arguments.Named.Item("cmd")
argAgentType = WScript.Arguments.Named.Item("type")
argMonitors = WScript.Arguments.Named.Item("monitors")
argApiKey = WScript.arguments.named.item("apiKey")
argSecretKey = WScript.arguments.named.item("secretKey")
argProcesses = WScript.arguments.named.item("process")

'Main routine
Select Case LCase(argCmd)
	Case "help"
		ShowUsage("Command Line Help")
		
	Case "listagents"
		ListAgents argAgentType, argMonitors, argProcesses
		ShowAgents
		
	Case "setkeys"
		If Len(argApiKey) = 0 Then
			ShowUsage "Missing APIKey"
		ElseIf Len(secretKey) = 0 Then
			ShowUsage "Missing SecretKey"
		Else
			SetAuthenticationKeys argApiKey, argSecretKey
		End If
		
	Case "getkeys"
		GetAuthenticationKeys(True)
	
	Case Else
		ShowUsage "Missing command"
End Select

'-------------------------------------------------------------------------
'Cleanup
Set Agents = Nothing
Set SupportedMonitors = Nothing
Set ShowMonitors = Nothing
Set ShowProcesses = Nothing

'-------------------------------------------------------------------------

Sub ListAgents(agentType, argMonitors, argProcesses)
	'Initialize HTTP connection object
	Set objHttp = CreateObject("Microsoft.XMLHTTP")
	
	'Setup the keys and authentication token
	GetAuthenticationKeys False
	authToken = GetAuthToken(objHttp, apiKey, secretKey)
	
	'Process monitor(s) command line parameter
	If LCase(argMonitors) = "all" Then
		If LCase(agentType) = "fullpage" Then
			tempList = Split(argMonitors, ",")
			If Not ShowMonitors.Exists(LCase(tempList(i))) Then
				ShowMonitors.Add tempList(i), tempList(i)
			End If
		Else
			For Each monitor In SupportedMonitors
				ShowMonitors.Add monitor, monitor
			Next
		End If
	ElseIf Len(argMonitors) > 0 Then
		tempList = Split(argMonitors, ",")
		For i = 0 To UBound(tempList)
			If Not ShowMonitors.Exists(LCase(tempList(i))) Then
				ShowMonitors.Add tempList(i), tempList(i)
			End If
		Next
	ElseIf Len(argProcesses) > 0 Then
		tempList = Split(argProcesses, ",")
		For i = 0 To UBound(tempList)
			If Not ShowProcesses.Exists(LCase(tempList(i))) Then
				ShowProcesses.Add tempList(i), tempList(i)
			End If
		Next
	Else
		ShowUsage "Error: you must specify a monitor or process"
		WScript.Quit
	End If	
	
	
	Select Case LCase(agentType)
		Case "int"
			GetInternalAgents objHttp, Agents, ShowMonitors, ShowProcesses
		
		Case "ext"
			GetExternalMonitors objHttp, Agents, ShowMonitors
		
		Case "fullpage"
			GetFullpageMonitors objHttp, Agents, ShowMonitors

		Case "all"
			GetInternalAgents objHttp, Agents, ShowMonitors, ShowProcesses
			GetExternalMonitors objHttp, Agents, ShowMonitors
			GetFullpageMonitors objHttp, Agents, ShowMonitors
			
		Case Else
			GetInternalAgents objHttp, Agents, ShowMonitors, ShowProcesses
	End Select
	
End Sub

'-------------------------------------------------------------------------

Sub ShowUsage(strError)
	WScript.Echo "Error: " & strError
	WScript.Echo "See usage examples below"
	WScript.Echo ""
	WScript.Echo "Show command line help:"
	WScript.Echo "/cmd:help"
	WScript.Echo ""
	WScript.Echo "View APIKey and SecretKey values:"
	WScript.Echo "/cmd:getkeys"
	WScript.Echo ""
	WScript.Echo "Set APIKey and SecretKey:"
	WScript.Echo "/cmd:setkeys /apikey:<apikey> /secretkey:<secretKey>"
	WScript.Echo ""
	WScript.Echo "Show global monitor results for defined agents:"
	WScript.Echo "/cmd:listagents /type:<int>|<ext>|<fullpage>|<all> [/monitors:<all><name>,<name>,...]"
	WScript.Echo ""
	WScript.Echo "Show monitor results for one or more specific processes:"
	WScript.Echo "/cmd:listagents /type:<int>|<ext>|<all> [/process:<name>,<name>,...]"
	WScript.Echo ""
	WScript.Echo "Example:"
	WScript.Echo "Show cpu and memory monitors for all internal agents"
	WScript.Echo "/cmd:listagents /type:int /monitors:cpu,memory"
End Sub

'-------------------------------------------------------------------------

Sub Include(strFilename)
	On Error Resume Next
	Dim oFSO, f, s

	Set oFSO = CreateObject("Scripting.FileSystemObject")
	If oFSO.FileExists(strFilename) Then
		Set f = oFSO.OpenTextFile(strFilename)
		s = f.ReadAll
		f.Close
		ExecuteGlobal s
	End If

	Set oFSO = Nothing
	Set f = Nothing
	On Error Goto 0
End Sub

'-----------------------------------------------------------------------------------------------
	
Sub ShowAgents
	'Write the list of agents to the screen	
	For Each agent In Agents.Items
		WScript.Echo "" 
		WScript.Echo "-------------------------------------------------------------------------------"
		WScript.Echo " AGENT: " & agent.Name
		WScript.Echo "-------------------------------------------------------------------------------"

		'Determine the width of the column for the display name of the monitor
		maxMonitorWidth = 0
		maxMetricWidth = 0
		For Each monitor In agent.MonitorList.Items
			If Len(Monitor.DisplayName) > maxMonitorWidth Then
				maxMonitorWidth = Len(Monitor.DisplayName)+4
			End If
			
			For Each objMetric In Monitor.MetricList.Items
				If Len(objMetric.Name) > maxMetricWidth Then
					maxMetricWidth = Len(objMetric.Name)+4
				End If
			Next
		Next
		
		'Build the output strings to show the monitor data
		strTemp = "*"
		strHeader = ""
		strRow = ""
		For Each monitor In agent.MonitorList.Items
			strHeader = format(Monitor.DisplayName, maxMonitorWidth)
			strRow = format(" ", maxMonitorWidth)
			
			For Each objMetric In Monitor.MetricList.Items
				strHeader = strHeader & format(objMetric.Name, maxMetricWidth)
				strRow = strRow & format(objMetric.Result & objMetric.Suffix, maxMetricWidth)
			Next

			WScript.Echo strHeader
			WScript.Echo strRow
			WScript.Echo ""
		Next

	Next
End Sub

'-----------------------------------------------------------------------------------------------

Function GetResult(aNode, aMonitor, aFields)
	arrValues = Split(aFields, "|")
	For Each value In arrValues 
	
		'Split each value in the API field name and the suffix string 
		arrDetails = Split(value,",")
		strValue = arrDetails(0)
		strSuffix = arrDetails(1)
	
		'Retrieve the result for the given counter
		Set t = aNode.selectSingleNode(strValue)
		If Not t Is Nothing Then
			
			'Create a new metric object
			Set Metric = New class_Metric
			Metric.Name = strValue
			Metric.Result = t.text & strSuffix
			
			'Add the metric object to the current monitor object
		 	aMonitor.MetricList.Add Metric.Name, Metric
		End If
	
	Next
End Function
