'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'
'  FBManageLog.vbs  
'  Copyright FineBuild Team � 2017 - 2018.  Distributed under Ms-Pl License
'
'  Purpose:      Manage the FineBuild Log File 
'
'  Author:       Ed Vassie
'
'  Date:         05 Jul 2017
'
'  Change History
'  Version  Author        Date         Description
'  1.0      Ed Vassie     05 Jul 2017  Initial version

'
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Option Explicit
Dim FBManageLog: Set FBManageLog = New FBManageLogClass

Dim objLogFile
Dim strDebug, strDebugDesc, strDebugMsg1, strDebugMsg2
Dim strMsgError, strMsgWarning, strMsgInfo
Dim strProcessId, strProcessIdCode, strProcessIdDesc, strProcessIdLabel
Dim strSetupLog, strStatusBypassed, strStatusComplete, strStatusFail, strStatusManual, strStatusPreConfig, strStatusProgress

Class FBManageLogClass
Dim objFSO, objShell 
Dim strLogTxt, strStopAt


Private Sub Class_Initialize
  Call DebugLog("FBManageLog Class_Initialize:")

  Set objFSO        = CreateObject("Scripting.FileSystemObject")
  Set objShell      = WScript.CreateObject ("Wscript.Shell")
  Call LogSetup()

  strDebugDesc      = ""
  strDebugMsg1      = ""
  strDebugMsg2      = ""
  strProcessIdCode  = ""
  strProcessIdDesc  = ""
  strSetupLog       = Left(strLogTxt, InStrRev(strLogTxt, "\"))

End Sub


Sub DebugLog(strDebugText)

  strDebugDesc      = strDebugText

  Select Case True
    Case strDebug <> "YES"
      ' Nothing
    Case Not IsObject(objLogFile)
      ' Nothing
    Case Else
      Call LogWrite(strDebugText)
  End Select

  strDebugMsg1      = ""
  strDebugMsg2      = ""

End Sub


Sub FBLog(strLogText)

  If Left(strProcessIdLabel, 1) > "0" Then
    Wscript.Echo LogFormat(strLogText, "E")
  End If

  Call LogWrite(strLogText)

End Sub


Function CheckStatus(strInstName)
  Dim binStatus
  Dim strStatus

  strStatus         = "Setup" & strInstName & "Status"
  Select Case True
    Case GetBuildfileValue(strStatus) = strStatusComplete
      binStatus     = True
    Case GetBuildfileValue(strStatus) = strStatusPreConfig
      binStatus     = True
    Case Else
      binStatus     = False
  End Select

  CheckStatus       = binStatus

End Function


Private Function LogFormat(strLogText, strDest)
  Dim strId, strLogFormat

  Select Case True
    Case strDest <> "E"
      strLogFormat  = CStr(Date()) & " "
    Case Else
      strLogFormat  = ""
  End Select

  Select Case True
    Case strProcessIdCode = "FBCV"
      strId         = ""
    Case strProcessIdCode = "FBCR"
      strId         = ""
    Case Else
      strId         = strProcessIdLabel & ":"
  End Select
  strLogFormat      = strLogFormat & CStr(Time()) & " " & Left(strProcessIdCode & "****", 4) & " " & Left(strId & "       ", 7) & HidePasswords(strLogText)

  LogFormat         = strLogFormat

End Function


Private Sub LogSetup()

  strLogTxt         = Ucase(objShell.ExpandEnvironmentStrings("%SQLLOGTXT%"))
  Select Case True
    Case strLogTxt = ""
      ' Nothing
    Case strLogTxt = "%SQLLOGTXT%"
      ' Nothing
    Case Else
      Set objLogFile     = objFSO.GetFile(Replace(strLogTxt, """", ""))
      strDebug           = GetBuildfileValue("Debug")
      strMsgError        = GetBuildfileValue("MsgError")
      strMsgInfo         = GetBuildfileValue("MsgInfo")
      strMsgWarning      = GetBuildfileValue("MsgWarning")
      strProcessId       = GetBuildfileValue("ProcessId")
      strProcessIdLabel  = GetBuildfileValue("ProcessId")
      strStatusBypassed  = GetBuildFileValue("StatusBypassed")
      strStatusComplete  = GetBuildFileValue("StatusComplete")
      strStatusFail      = GetBuildfileValue("StatusFail")
      strStatusManual    = GetBuildfileValue("StatusManual")
      strStatusPreConfig = GetBuildFileValue("StatusPreConfig")
      strStatusProgress  = GetBuildFileValue("StatusProgress")
      strStopAt          = GetBuildfileValue("StopAt")
  End Select

End Sub


Private Sub LogWrite(strLogText)
  Dim objLogStream

  Set objLogStream  = objLogFile.OpenAsTextStream(8, -2)
  objLogStream.WriteLine LogFormat(strLogText, "F")
  objLogStream.Close

End Sub


Private Function HidePassword(strText, strKeyword)
  ' Change any passwords to ********
  Dim intIdx, intFound, intLen
  Dim strLogText

  strLogText        = strText
  intLen            = Len(strLogText)
  intIdx = Instr(1, strLogText, strKeyword, vbTextCompare)
  While intIdx > 0
    intFound        = 0
    intIdx          = intIdx + Len(strKeyword)
    While (Instr(""":=' ", Mid(strLogText, intIdx, 1)) > 0 ) And (intIdx < intLen)
      intIdx        = intIdx + 1
      intFound      = 1
    Wend
    While (Instr(""",/' ", Mid(strLogText, intIdx, 1)) = 0) And (IntFound > 0)
      strLogText    = Left(strLogText, intIdx - 1) & Chr(01) & Mid(strLogText, intIdx + 1)
      intIdx        = intIdx + 1
    Wend
    intIdx          = Instr(intIdx, strLogText, strKeyword, vbTextCompare)
  WEnd
  While Instr(strLogText, Chr(01) & Chr(01)) > 0
    strLogText      = Replace(Replace(Replace(strLogText, Chr(01) & Chr(01) & Chr(01) & Chr(01), Chr(01)), Chr(01) & Chr(01) & Chr(01), Chr(01)), Chr(01) & Chr(01), Chr(01))
  Wend
  strLogText        = Replace(strLogText, Chr(01), "**********")
  HidePassword      = strLogText

End Function


Function HidePasswords(strText)
  ' Hide passwords in Text string
  Dim strLogText

  strLogText        = strText
  strLogText        = HidePassword(strLogText, "Password")
  strLogText        = HidePassword(strLogText, "PID")
  strLogText        = HidePassword(strLogText, "Pwd")
  strLogText        = HidePassword(strLogText, " -p ")
  strLogText        = HidePassword(strLogText, "StreamInsightPID")
  strLogText        = HidePassword(strLogText, "DefaultPassword /d ")
  HidePasswords     = strLogText

End Function


Sub SetProcessId(strLabel, strDesc)
' Save ProcessId details

  strProcessIdLabel = strLabel
  strProcessIdDesc  = strDesc

  Select Case True
    Case Left(strProcessIdLabel, 1) = "0"
      Call LogWrite(strDesc)
    Case Right(strDesc, Len(strStatusComplete)) = strStatusComplete
      Call LogWrite(strDesc)
    Case Else
      Call FBLog(strDesc)
  End Select

  If Left(strProcessIdLabel, 1) > "0" Then
    Call SetBuildfileValue("ProcessId",     strProcessIdLabel)
    Call SetBuildfileValue("ProcessIdDesc", strProcessIdDesc)
    Call SetBuildfileValue("ProcessIdTime", Cstr(Time()))
  End If

  strDebugDesc      = ""
  strDebugMsg1      = ""
  strDebugMsg2      = ""

End Sub


Sub SetProcessIdCode(strCode)
' Save ProcessId code

  strProcessIdCode  = strCode

End Sub


Sub ProcessEnd(strStatus)

  If strStatus <> "" Then
    Call LogWrite(" " & strProcessIdDesc & strStatusComplete)
  End If

  If (strStopAt = "AUTO") Or (strStopAt <> "" And strStopAt <= strProcessIdLabel) Then
    err.Raise 4, "", "Stop forced at: " & strProcessIdDesc
  End If

End Sub


End Class


Sub DebugLog(strDebugText)
  Call FBManageLog.DebugLog(strDebugText)
End Sub

Sub FBLog(strText)
  Call FBManageLog.FBLog(strText)
End Sub

Function CheckStatus(strInstName)
  CheckStatus       = FBManageLog.CheckStatus(strInstName)
End Function

Function HidePasswords(strText)
  HidePasswords     = FBManageLog.HidePasswords(strText)
End Function

Sub SetProcessId(strLabel, strDesc)
  Call FBManageLog.SetProcessId(strLabel, strDesc)
End Sub

Sub SetProcessIdCode(strCode)
  Call FBManageLog.SetProcessIdCode(strCode)
End Sub

Sub ProcessEnd(strStatus)
  Call FBManageLog.ProcessEnd(strStatus)
End Sub