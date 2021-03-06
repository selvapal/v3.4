''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'
'  FBConfigVar.vbs  
'  Copyright FineBuild Team © 2008 - 2018.  Distributed under Ms-Pl License
'
'  Purpose:      Setup specified variable for FineBuild.bat
'
'  Author:       Ed Vassie
'
'  Date:         01 Jan 2008
'
'  Change History
'  Version  Author        Date         Description
'  1.3.0    Ed Vassie     19 Apr 2013  Population of BuildFile moved to SqlValidate
'  1.2.1    Ed Vassie      8 Mar 2012  Updates for FineBuild v3.0.3
'  1.2.0    Ed Vassie     16 May 2011  Added Buildfile processing
'  1.1.0    Ed Vassie     16 Aug 2008  Improved error handling
'                                      Changes as required for SQL Server 2008
'  1.0.2    Ed Vassie     20 Feb 2008  Added VarName=Edition procesing 
'  1.0.1    Ed Vassie     10 Feb 2008  Added VarName=ProcessId procesing 
'  1.0.0    Ed Vassie     02 Feb 2008  Initial version for FineBuild v1.0
'
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Option Explicit
Dim SQLBuild : Set SQLBuild = New FineBuild

Class FineBuild

Dim colArgs, colBuild, colBuildFile, colFiles, colFlags, colGlobal, colStrings, colSysEnvVars
Dim objBuildFile, objConfig, objDrive, objFSO, objShell, objWMI, objWMIReg
Dim strBuildFile, strConfig, strCmd
Dim strDebug, strDebugDesc, strDirProg, strDrive, strVolFBLog, strVolProg, strVolSys, strEdition, strFBCmd, strFBParm, strFilePerm
Dim strHKLM, strInstance, strInstNode, strLogFile, strMsgError, strMsgWarning, strMsgInfo, strOSName, strOSVersion
Dim strParmInject, strPath, strPathFB, strPathSys, strProcessId, strProcessIdLabel, strProcessIdSave, strProgCacls
Dim strReportFile, strReportOnly, strRestart, strServer, strSQLProgDir, strSQLVersion, strStopAt, strTemp, strType
Dim strUserConfiguration, strUserConfigurationvbs, strUserName, strUserPreparation, strUserPreparationvbs, strVarName, strVersionFB, strXMLNode

Private Sub Class_Initialize
' Perform FineBuild processing

  err.Clear
  Call Initialisation()

  Select Case True
    Case err.Number <> 0 
      ' Nothing
    Case Else
      Call ProcessVar()
  End Select

End Sub


Private Sub Class_Terminate
' Error handling and termination
  Dim strErrMessage

  Select Case True
    Case err.Number = 0 
      ' Nothing
    Case Else
      If err.Source = "" Then
        strErrMessage = "Error " & err.Number & ": " & err.Description
      Else
        strErrMessage = err.Source & ": " & err.Description
      End If
      Wscript.Echo strErrMessage
      If strDebugDesc <> "" Then
        Wscript.Echo " Last Action: " & strDebugDesc
      End If
  End Select

  Wscript.Quit(err.Number)

End Sub


Sub Initialisation ()
' Perform initialisation procesing

  Set objShell      = WScript.CreateObject ("Wscript.Shell")
  strPathFB         = objShell.ExpandEnvironmentStrings("%SQLFBFOLDER%")
  Include "FBManageBuildfile.vbs"
  Include "FBManageLog.vbs"
  Call SetProcessIdCode("FBCV")

  Set objBuildfile  = CreateObject ("Microsoft.XMLDOM")  
  Set objConfig     = CreateObject ("Microsoft.XMLDOM")  
  Set objFSO        = CreateObject ("Scripting.FileSystemObject")
  Set objWMI        = GetObject("winmgmts:{impersonationLevel=impersonate,(Security)}!\\.\root\cimv2")
  Set objWMIReg     = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
  Set colSysEnvVars = objShell.Environment("System")
  Set colArgs       = Wscript.Arguments.Named

  strSQLVersion     = Ucase(objShell.ExpandEnvironmentStrings("%SQLVERSION%"))
  strSQLVersion     = Ucase(GetParam(Null,              "SQLVersion",         strSQLVersion))
  objBuildFile.async = False
  strConfig         = GetParam(Null,                    "Config",             strSQLVersion & "Config.xml")
  objConfig.async   = False
  objConfig.load(strPathFB & strConfig)

  strType           = Ucase(GetParam(Null,              "Type",               "FULL"))
  Select Case True
   Case objConfig.parseError.errorCode <> 0
     Err.Raise objConfig.parseError.errorCode, "", "Error opening " & strPathFB & strConfig & ": " & objConfig.parseError.reason
    Case err.Number <> 0
    Case strType = "CLIENT" 
      strXMLNode    = "BuildClient"
    Case strType = "WORKSTATION" 
      strXMLNode    = "BuildWorkstation"
    Case Else
      strXMLNode    = "BuildServer"
  End Select
  Set colGlobal     = objConfig.documentElement.selectSingleNode("Global")
  Set colBuild      = objConfig.documentElement.selectSingleNode(strXMLNode)
  Set colFlags      = objConfig.documentElement.selectSingleNode(strXMLNode & "/Flags")
  Set colFiles      = objConfig.documentElement.selectSingleNode("Files")
  Set colStrings    = objConfig.documentElement.selectSingleNode("Global/Strings")

  strHKLM           = &H80000002
  strEdition        = Ucase(GetParam(Null,              "Edition",            "Enterprise Evaluation"))
  strInstance       = Ucase(GetParam(Null,              "Instance",           ""))
  Select Case True
    Case strInstance <> ""
      ' Nothing
    Case strEdition = "EXPRESS"
      strInstance   = "SQLEXPRESS"
    Case Else
      strInstance   = "MSSQLSERVER"
  End Select

  strProgCacls      = GetParam(colGlobal,               "Cacls",              "CACLS")
  strFBParm         = objShell.ExpandEnvironmentStrings("%SQLFBPARM%")
  strFilePerm       = GetParam(colGlobal,               "FilePerm",           "")
  strDebug          = Ucase(GetParam(Null,              "Debug",              ""))
  strFBCmd          = objShell.ExpandEnvironmentStrings("%SQLFBCMD%")
  strMsgError       = UCase(GetParam(colStrings,        "MsgError",           "ERROR"))
  strMsgInfo        = UCase(GetParam(colStrings,        "MsgInfo",            "INFO"))
  strMsgWarning     = UCase(GetParam(colStrings,        "MsgWarning",         "WARNING"))
  strOSName         = objShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName")
  strOSVersion      = objShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentVersion")
  strPathSys        = objShell.ExpandEnvironmentStrings("%PROGRAMFILES%")
  strRestart        = Ucase(GetParam(Null,              "Restart",            ""))
  strReportOnly     = Ucase(GetParam(Null,              "ReportOnly",         ""))
  strSQLProgDir     = GetParam(colStrings,              "SQLProgDir",         "Microsoft SQL Server")
  strServer         = objShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
  strStopAt         = Ucase(GetParam(Null,              "StopAt",         ""))
  strUserName       = objShell.ExpandEnvironmentStrings("%USERNAME%")
  strVarName        = Ucase(GetParam(Null,              "VarName",            ""))
  strVersionFB      = objShell.ExpandEnvironmentStrings("%SQLFBVERSION%")
  strVolSys         = Left(objShell.ExpandEnvironmentStrings("%SYSTEMDRIVE%"), 1)

End Sub


Function GetParam(colParam, strParam, strDefault) 
' Get parameter value
Dim strValue

' Find parameter value in XML configuration file
  Select Case True
    Case IsNull(colParam)
      strValue      = strDefault
    Case IsNull(colParam.getAttribute(strParam))
      strValue      = strDefault
    Case Else
      strValue      = colParam.getAttribute(strParam)
  End Select

' Apply any parameter overide from CSCRIPT arguments
  Select Case True
    Case Not colArgs.Exists(strParam)
      ' Nothing
    Case Else
      strValue      = colArgs.Item(strParam)
  End Select

  GetParam          = strValue

End Function


Sub ProcessVar()
  Call DebugLog("Process Var: " & strVarName & " (FBConfigVar.vbs)")

  Select Case True
    Case strVarName = "CRASHID" 
      Call GetCrashId()
    Case strVarName = "DEBUG" 
      Call SetDebug()
    Case strVarName = "EDITION" 
      Call SetEdition()
    Case strVarName = "FBPARM" 
      Call SetFBParm()
    Case strVarName = "LOGFILE" 
      Call PrepareLogFile()
    Case strVarName = "LOGVIEW" 
      Call ViewLogFile()
    Case strVarName = "PATH" 
      Call SetPath()
    Case strVarName = "PROCESSID" 
      Call SetProcessId()
    Case strVarName = "REPORTVIEW" 
      Call ViewReportFile()
    Case strVarName = "TEMP" 
      Call SetTemp()
    Case strVarName = "TYPE" 
      Call SetType()
    Case strVarName = "USERCONFIGURATION" 
      Call GetUserConfiguration()
    Case strVarName = "USERPREPARATION" 
      Call GetUserPreparation()
    Case Else
      err.Raise 8, "",  "Unknown variable type: " & strVarName
  End Select

End Sub


Sub GetCrashId()
  Call DebugLog("Get ProcessId where crash occurred")
  Dim strCrashId

  Call LinkBuildFile("")
  strCrashId        = GetBuildfileValue("ProcessId")
  
  Wscript.Echo " """ & strCrashId & """"

End Sub


Sub SetDebug ()
  Call DebugLog("Setup Debug flag")

  Select Case True
    Case colArgs.Exists("Debug")
      ' Nothing
    Case Instr(strVersionFB, "B") > 0
      strDebug      = "YES"
  End Select

  Call LinkBuildFile("")

  Select Case True
    Case strDebug = "FULL"
      strDebug      = "YES"
      Wscript.Echo " //X"
    Case Else
      Wscript.Echo " "
  End Select

  Call SetBuildfileValue("Debug",             strDebug)

End Sub


Sub SetEdition ()
  Call DebugLog("Setup SQL Server Edition value")

  Wscript.Echo " """ & strEdition & """"

End Sub


Sub SetFBParm()
  Call DebugLog("Setup FB Parameter")
  Dim strFBParmOld, strFBParmSave

  Call LinkBuildFile("")
  strFBParm         = MinifyParm(strFBParm)
  strFBParmOld      = GetBuildfileValue("FBParmOld")
  strFBParmSave     = GetBuildfileValue("FBParm")
  strParmInject     = ""
  strRestart        = GetBuildfileValue("RestartSave")

  Select Case True
    Case colArgs.Exists("ReportOnly")
      ' Nothing
    Case Else
      strParmInject = strParmInject & " /ReportOnly:NO"
  End Select
  Select Case True
    Case colArgs.Exists("Restart") 
      ' Nothing
    Case Else
      strParmInject = strParmInject & " /Restart:"""""
  End Select
  Select Case True
    Case colArgs.Exists("StopAt")
      ' Nothing
    Case Else
      strParmInject = strParmInject & " /StopAt:"""""
  End Select

  Select Case True
    Case strFBParmSave = ""
      ' Nothing
    Case strRestart = "NO"
      Call SetBuildfileValue("FBParmOld",     "")
    Case strFBParm = strFBParmOld
      strFBParm     = strFBParmSave
    Case Else
      Call SetBuildfileValue("FBParmOld",     strFBParm)
      strFBParm     = strFBParm & strParmInject & " " & strFBParmSave
  End Select

  Wscript.Echo " " & strFBParm

End Sub


Function MinifyParm(strParm)
  Call DebugLog("Minify parm " & strParm)
  Dim strMinify, strWork

  strMinify         = strParm
  strWork           = ""
  While strWork <> strMinify
    strWork         = strMinify
    strMinify       = Replace(strWork, "  /", " /")
  WEnd

  MinifyParm        = strMinify

End Function


Sub PrepareLogFile()
  Call DebugLog("Setup Log File for SQL install")
  Dim colGroup, colProcs
  Dim objAccount,objExec, objMember, objProc
  Dim strGroupAdmin, strGroupUsers, strFBFolder, strPathLog, strUserAdmin, strUser, strUserSID

  Set objAccount    = objWMI.Get("Win32_SID.SID='S-1-5-32-544'") ' Local Administrators
  strGroupAdmin     = objAccount.AccountName
  Set objAccount    = objWMI.Get("Win32_SID.SID='S-1-5-32-545'") ' Local Users
  strGroupUsers     = objAccount.AccountName
  strFilePerm       = Replace(Replace(strFilePerm, "Administrators", strGroupAdmin),"Users", strGroupUsers)
  strPathLog        = strPathSys
  strVolFBLog       = strVolSys

  strFBFolder       = Left(strFBCmd, InstrRev(strFBCmd, "\"))
  strUserAdmin      = "NO"
  strUserSID        = ""
  Set colProcs      = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Description='cscript.exe'")
  For Each objProc In colProcs
    If Instr(objProc.CommandLine, strFBFolder) > 0 Then
      objProc.GetOwner    strUser
      objProc.GetOwnerSid strUserSID
    End If
  Next

  Select Case True
    Case (InStr(1, strUserSID, "S-1-5-18", vbTextCompare) > 0) ' Local System
      strUserAdmin  = "YES"
    Case (InStr(1, strUserSID, "S-1-5-20", vbTextCompare) > 0) ' Network Service
      strUserAdmin  = "YES"
    Case Instr(Ucase(strOSName), " XP") > 0
      Set colGroup  = GetObject("WinNT://./" & strGroupAdmin & ",group")
      For Each objMember In colGroup.Members
        If strUser = objMember.Name Then
          strUserAdmin = "YES"
        End If
      Next
    Case Else
      Set objExec   = objShell.Exec("whoami /groups")
      strCmd        = objExec.StdOut.ReadAll
      Select Case True
        Case (strOSVersion >= "6") And (InStr(1, strCmd, "S-1-16-12288", vbTextCompare) > 0)
          strUserAdmin  = "YES"
        Case (strOSVersion < "6")  And (InStr(1, strCmd, "S-1-5-32-544", vbTextCompare) > 0)
          strUserAdmin  = "YES"
        Case Else
          strUserAdmin = "NO"
          strPathLog   = objShell.ExpandEnvironmentStrings("%TEMP%")
          strVolFBLog  = Left(strPathLog, 1)
      End Select
  End Select

  strPathLog        = strVolFBLog & Mid(strPathLog, 2)
  Call CreateThisFolder(strPathLog)
  If strUserAdmin = "YES" Then
    strPathLog      = strPathLog & "\" & strSQLProgDir
    Call CreateThisFolder(strPathLog)
  End If
  strPathLog        = strPathLog & "\FineBuildLogs"
  Call CreateThisFolder(strPathLog)
  strCmd            = strProgCacls & " """ & strPathLog & """ /E /T /C /P " & strFilePerm
  err.Number        = objShell.Run("%COMSPEC% /D /C Echo Y| " & strCmd, 7, True)
  strLogFile        = strPathLog & "\FineBuildInstall" & strType & strInstance & ".txt"
  If Not objFSO.FileExists(strLogFile) Then
    Call SetupLogfile(strLogFile)
    Call SetupBuildfile(strLogFile)
  End If

  Call LinkBuildFile("""" & strLogFile & """")

  strProcessIdSave  = GetBuildfileValue("ProcessId")
  Select Case True
    Case strRestart = "AUTO" 
      strRestart    = "YES"
    Case strRestart <> ""
      ' Nothing
    Case (strProcessIdSave = "") Or (strProcessIdSave = "1")
      strRestart    = "NO"
    Case Else ' Automatically set /Restart:YES if FineBuild restarted without a /Restart: parameter
      strRestart    = "YES"
  End Select
  Call SetBuildfileValue("RestartSave",        strRestart)

  If strRestart = "NO" Then
    Call SetupLogfile(strLogFile)
    Call SetupBuildfile(strLogFile)
  End If

  Call SetFBPath()
  Call SetBuildfileValue("AuditUser",          strUserName)
  Call SetBuildfileValue("UserAdmin",          strUserAdmin)
  Call SetBuildfileValue("UserSID",            strUserSID)

  Wscript.Echo " """ & strLogFile & """"

End Sub


Sub SetupLogfile(strLogFile)
  Call DebugLog("Setup Logfile for SQL install")
  Dim objLogFile

  If objFSO.FileExists(strLogFile) Then
     Call objFSO.DeleteFile(strLogFile, True)
     Wscript.Sleep 500
  End If

  Set objLogFile    = objFSO.CreateTextFile(strLogFile, True)
  objLogfile.WriteLine "# Software:  SQL FineBuild " & strVersionFB
  objLogfile.WriteLine "# Server:    " & strServer
  objLogfile.WriteLine "# User:      " & strUserName
  objLogfile.WriteLine "# StartDate: " & CStr(Date())
  objLogfile.WriteLine "# Fields:    date, time, method, comment"
  objLogfile.Close

End Sub


Sub SetupBuildfile(strLogFile)
  Call DebugLog("Setup Buildfile for SQL install")

  strPath           = strPathFB & "Build Scripts\FineBuild.xml"
  strBuildFile      = Left(strLogFile, Len(strLogFile) - 4) & ".xml"
  objFSO.CopyFile strPath, strBuildFile, True
  objBuildfile.load(strBuildFile)
  Set colBuildFile  = objBuildfile.documentElement.selectSingleNode("BuildFile")

  strProcessId      = "1"
  strReportFile     = Left(strBuildFile, Len(strBuildFile) - 4) & "Report.txt"

  Select Case True
    Case strEdition = "BI"
      strEdition    = "BUSINESS INTELLIGENCE"
    Case strEdition = "DC"
      strEdition    = "DATA CENTER"
    Case strEdition = "DEV"
      strEdition    = "DEVELOPER"
    Case strEdition = "EXP"
      strEdition    = "EXPRESS"
    Case strEdition = "ENT"
      strEdition    = "ENTERPRISE"
    Case strEdition = "EVALUATION"
      strEdition    = "ENTERPRISE EVALUATION"
    Case strEdition = "EVAL"
      strEdition    = "ENTERPRISE EVALUATION"
    Case strEdition = "STD"
      strEdition    = "STANDARD"
    Case strEdition = "WKG"
      strEdition    = "WORKGROUP"
  End Select

  Call SetBuildfileValue("AuditBuild",         strType)
  Call SetBuildfileValue("AuditStartDate",     Cstr(Date()))
  Call SetBuildfileValue("AuditStartTime",     CStr(Time()))
  Call SetBuildfileValue("AuditServer",        strServer)
  Call SetBuildfileValue("AuditVersion",       strSQLVersion)
  Call SetBuildfileValue("AuditEdition",       strEdition) 
  Call SetBuildfileValue("EditionOrig",        strEdition) 
  Call SetBuildfileValue("FilePerm",           strFilePerm) 
  Call SetBuildfileValue("Config",             strConfig)
  Call SetBuildfileValue("Instance",           strInstance)
  Call SetBuildfileValue("MsgError",           strMsgError)
  Call SetBuildfileValue("MsgInfo",            strMsgInfo)
  Call SetBuildfileValue("MsgWarning",         strMsgWarning)
  Call SetBuildfileValue("ProcessId",          strProcessId)
  Call SetBuildfileValue("ReportFile",         strReportFile)
  Call SetBuildfileValue("Type",               strType)
  Call SetBuildfileValue("TypeNode",           strXMLNode)
  Call SetBuildfileValue("VersionFB",          strVersionFB)
  
End Sub


Sub SetFBPath()
  Call DebugLog("Set Path to FineBuild Components")
  Dim objVol
  Dim strFBLocal, strFBRemote, strPath

  strFBLocal        = UCase(Left(strPathFB, 2))
  Call SetBuildfileValue("FBPathLocalPrev", GetBuildfileValue("FBPathLocal"))
  Call SetBuildfileValue("FBPathLocal",     strFBLocal)

  Set objVol        = objWMI.Get("Win32_LogicalDisk.DeviceId='" & strFBLocal & "'")
  Select Case True
    Case Not IsObject(objVol)
      Call SetBuildfileValue("FBPathRemote", strFBLocal)
    Case IsNull(objVol.ProviderName)
      Call SetBuildfileValue("FBPathRemote", strFBLocal)
    Case Else
      Call SetBuildfileValue("FBPathRemote", UCase(objVol.ProviderName))
  End Select

End Sub


Sub ViewLogFile()
  Call DebugLog("View the FineBuild log file")

  Call LinkBuildFile("")

  strLogFile        = Replace(objShell.ExpandEnvironmentStrings("%SQLLOGTXT%"), """", "")
  Select Case True
    Case strOSVersion < "6"
      strCmd        = "NOTEPAD.EXE " & strLogFile
    Case GetBuildfileValue("UserAdmin") <> "YES"
      strCmd        = "NOTEPAD.EXE " & strLogFile
    Case Else
      strCmd        = "RUNAS /TrustLevel:0x20000 ""NOTEPAD.EXE \""" & strLogFile & "\"""""
  End Select
  err.Number        = objShell.Run(strCmd, 1, False)

End Sub


Sub SetPath ()
  Call DebugLog("Set PATH value")

  strPath           = objShell.ExpandEnvironmentStrings(colSysEnvVars("PATH"))

  Wscript.Echo " " & strPath

End Sub


Sub SetProcessId ()
  Call DebugLog("Setup ProcessId value")
  Dim strReportSave

  Call LinkBuildFile("")
  strProcessIdSave  = GetBuildfileValue("ProcessId")
  strReportSave     = GetBuildfileValue("ReportOnly")
  strRestart        = GetBuildfileValue("RestartSave")

  Select Case True
    Case Not colArgs.Exists("ReportOnly")
      strReportOnly = "NO"
    Case strReportOnly = ""
      strReportOnly = "YES"
  End Select

  Select Case True
    Case strType = "DISCOVER"
      strProcessId = "D"
    Case strReportOnly = "YES"
      strProcessId = "7"
    Case (strReportOnly <> "YES") And (strReportSave = "YES")
      strProcessId  = "1"
    Case (strType = "CONFIG") And ((strRestart = "NO") Or (strProcessIdSave = "1"))
      strProcessId = "3"
    Case (strType = "CONFIG") And (strRestart = "YES")
      strProcessId = strProcessIdSave
    Case strType = "CONFIG"
      strProcessId = strRestart
    Case (strType = "FIX") And ((strRestart = "NO") Or (strProcessIdSave = "1"))
      strProcessId = "3"
    Case (strType = "FIX") And (strRestart = "YES")
      strProcessId = strProcessIdSave
    Case strType = "FIX"
      strProcessId = strRestart
    Case strRestart = "NO" 
      strProcessId  = "1"
    Case strRestart = "YES" 
      strProcessId  = strProcessIdSave
    Case Else
      strProcessId  = strRestart
  End Select

  Select Case True
    Case strProcessId = ""
      strProcessId  = "1"
    Case strType = "DISCOVER" And strProcessId = "D"
      ' Nothing
    Case strProcessId >= "6ZZ" 
      strProcessId  = "7"
  End Select
  Call SetBuildfileValue("ProcessId",  strProcessId)
  Call SetBuildfileValue("ReportOnly", strReportOnly)

  Select Case True
    Case strProcessId = ""
      Wscript.Echo " "
    Case Else
      Wscript.Echo " R" & Left(strProcessId, 1)
  End Select

End Sub


Sub ViewReportFile()
  Call DebugLog("View the FineBuild Configuration Report")
  Dim strReportFile

  Call LinkBuildFile("")

  strReportFile     = GetBuildfileValue("ReportFile")
  Select Case True
    Case strOSVersion < "6"
      strCmd        = "NOTEPAD.EXE """ & strReportFile & """"
    Case GetBuildfileValue("UserAdmin") <> "YES"
      strCmd        = "NOTEPAD.EXE """ & strReportFile & """"
    Case Else
      strCmd        = "RUNAS /TrustLevel:0x20000 ""NOTEPAD.EXE \""" & strReportFile & "\"""""
  End Select
  err.Number        = objShell.Run(strCmd, 1, False)

End Sub


Sub SetTemp ()
  Call DebugLog("Set TEMP value")

  strTemp           = objShell.ExpandEnvironmentStrings(colSysEnvVars("TEMP"))

  Wscript.Echo " " & strTemp

End Sub


Sub SetType ()
  Call DebugLog("Set TYPE value")

  Wscript.Echo " " & strType

End Sub


Sub GetUserConfiguration ()
  Call DebugLog("Get UserConfiguration variable")
  Dim strFBLocal, strFBRemote

  Call LinkBuildFile("")
  strFBLocal              = GetBuildfileValue("FBPathLocal")
  strFBRemote             = GetBuildfileValue("FBPathRemote")
  strProcessId            = GetBuildfileValue("ProcessId")
  strUserConfiguration    = GetBuildfileValue("UserConfiguration")
  strUserConfigurationvbs = GetBuildfileValue("UserConfigurationvbs")

  Select Case True
    Case strProcessId > "5ZZ"
      ' Nothing
    Case strUserConfiguration <> "YES"
      ' Nothing
    Case strUserConfigurationvbs = ""
      ' Nothing
    Case strFBLocal = strFBRemote
      ' Nothing
    Case UCase(Left(strUserConfigurationvbs, Len(strFBRemote))) = strFBRemote
        strUserConfigurationvbs = strFBLocal & Mid(strUserConfigurationvbs, Len(strFBRemote) + 1)
  End Select

  Wscript.Echo " """ & strUserConfigurationvbs & """"

End Sub


Sub GetUserPreparation ()
  Call DebugLog("Get UserPreparation variable")
  Dim strFBLocal, strFBRemote, strFileName

  Call LinkBuildFile("")
  strProcessId          = GetBuildfileValue("ProcessId")
  strFBLocal            = GetBuildfileValue("FBPathLocal")
  strFBRemote           = GetBuildfileValue("FBPathRemote")
  strUserPreparation    = GetBuildfileValue("UserPreparation")
  strUserPreparationvbs = GetBuildfileValue("UserPreparationvbs")

  Select Case True
    Case strProcessId > "1ZZ"
      ' Nothing
    Case strUserPreparation <> "YES"
      ' Nothing
    Case strUserPreparationvbs = ""
      ' Nothing
    Case strFBLocal = strFBRemote
      ' Nothing
    Case UCase(Left(strUserPreparationvbs, Len(strFBRemote))) = strFBRemote
        strUserPreparationvbs = strFBLocal & Mid(strUserPreparationvbs, Len(strFBRemote) + 1)
  End Select

  Wscript.Echo " """ & strUserPreparationvbs & """"

End Sub


Sub LinkBuildFile(strLogFile)
  Call DebugLog("Link to Buildfile")

  If strLogFile = "" Then
    strLogFile      = objShell.ExpandEnvironmentStrings("%SQLLOGTXT%")
  End If

  strBuildFile      = Mid(strLogFile, 2, Len(strLogFile) - 6) & ".xml"
  objBuildfile.load(strBuildFile)
  Set colBuildFile  = objBuildfile.documentElement.selectSingleNode("BuildFile")

End Sub


Function Include(strFile)
  Dim objFSO, objFile
  Dim strFilePath, strFileText

  Select Case True
    Case strPathFB = "%SQLFBFOLDER%"
      err.Raise 8, "", "ERROR: This process must be run by SQLFineBuild.bat"
    Case Else
      Set objFSO        = CreateObject("Scripting.FileSystemObject")
      strFilePath       = strPathFB & "Build Scripts\" & strFile
      Set objFile       = objFSO.OpenTextFile(strFilePath)
      strFileText       = objFile.ReadAll()
      objFile.Close 
      ExecuteGlobal strFileText
  End Select

End Function


Function GetBuildfileValue(strParam) 
  Call DebugLog("GetBuildfileValue: " & strParam)
  Dim strValue

  Select Case True
    Case IsNull(colBuildfile.getAttribute(strParam))
      strValue      = ""
    Case Else
      strValue      = colBuildfile.getAttribute(strParam)
  End Select

  GetBuildfileValue = strValue

End Function


Sub SetBuildfileValue (strName, strValue)
  Call DebugLog("Add Buildfile value " & strName & ": " & strValue)
  ' Code based on http://www.vbforums.com/showthread.php?t=480935
  Dim objAttribute

  If IsNull(strValue) Then
    strValue = ""
  End If

  Select Case True
    Case Not IsNull(colBuildfile.getAttribute(strName))
      colBuildfile.setAttribute strName, strValue
    Case Else
      Set objAttribute  = objBuildFile.createAttribute(strName)
      objAttribute.Text = strValue
      colBuildFile.Attributes.setNamedItem objAttribute
      objBuildFile.documentElement.appendChild colBuildfile
  End Select

  objBuildFile.save strBuildFile

End Sub


Sub CreateThisFolder (strFolderName)

  If Not objFSO.FolderExists(strFolderName) Then
    objFSO.CreateFolder(strFolderName)
    WScript.Sleep 500
    strCmd          = strProgCacls & " """ & strFolderName & """ /E /T /C /G " & strFilePerm
    err.Number      = objShell.Run("%COMSPEC% /D /C Echo Y| " & strCmd, 7, True)
  End If

End Sub


End Class