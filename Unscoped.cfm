<CFSETTING enablecfoutputonly="true" requesttimeout="30">
<!---
Location of unscoped.log is in the ColdFusion logs directory.
Place the hf*.jar file in [cfhome]\cfusion\libs\update

If running under commandbox, get the server root directory by entering "server info property=serverHomeDirectory"
The cfusion directory exists under [that dir]\WEB-INF

This script needs to run under the ColdFusion wwwroot or an app directory utilizing ColdFusion
--->

<!--- Load in any files marked as ignore --->
<CFSET IgnoreFiles="">
<CFIF FileExists("#ExpandPath('.')#/Unscoped_Ignore.txt")>
	<CFFILE action="read" file="#ExpandPath('.')#/Unscoped_Ignore.txt" variable="IgnoreFiles">
</CFIF>

<!--- Logic for updating the IgnoreFiles variable above --->
<CFPARAM name="URL.Ignore" default="">
<CFIF URL.Ignore NEQ "">
	<CFIF URL.Ignore EQ "Reset">
		<CFTRY>
			<CFFILE action="Delete" file="#ExpandPath('.')#/Unscoped_Ignore.txt">
			<CFCATCH Type="Any">
				<CFOUTPUT>Unable to delete "#ExpandPath('.')#/Unscoped_Ignore.txt"</CFOUTPUT>
				<CFABORT>
			</CFCATCH>
		</CFTRY>
	<CFELSE>
		<CFSET IgnoreFiles=ListAppend(IgnoreFiles,URL.Ignore,Chr(10))>
		<CFFILE action="write" file="#ExpandPath('.')#/Unscoped_Ignore.txt" output="#IgnoreFiles#" addnewline="NO">
	</CFIF>
	<CFLOCATION URL="Unscoped.cfm" addtoken="no">
</CFIF>

<!--- Identify the unscoped.log file --->
<CFSET UnscopeFile="#Server.coldfusion.rootdir#/logs/unscoped.log">
<CFIF Mid(UnscopeFile,2,1) EQ ":">
	<CFSET UnscopeFile=Replace(UnscopeFile,"/","\","ALL")>
</CFIF>
<CFIF FileExists("#UnscopeFile#") EQ "NO">
	<CFOUTPUT>File not found: #UnscopeFile#</CFOUTPUT>
	<CFABORT>
</CFIF>

<!--- If the path references in the unscoped.log file does not match where this program is running, set the current base path & override path to here. Use proper path delims, \ for windows, / for *nix --->
<CFSET OverrideBasePathFrom="">
<CFSET OverrideBasePathTo="">

<!--- load the unscope log file and parse it out --->
<CFFILE action="Read" file="#UnscopeFile#" variable="Unscoped">
<CFSET Unscoped=StripCR(Unscoped)>
<CFSET Unscoped=ListDeleteAt(Unscoped,1,Chr(10))>
<CFSET ScopeList="Arguments,Thread,CGI,cffile,URL,FORM,Cookie,Client">
<!--- The ` character in the following regex is replaced with the variable name currently being searched for --->
<CFSET VarRegEx="(<CF\w+\s.+?`\W.+?>|<CF\w+\s+?`\s[\s\S]+?>|<CF.+?##`##.+?>|##[\s\S]*?`[\s\S]*?##|<CFSET\s+`\s*=|<CFSET\s+[\s\S]+?=\s*`[\s\S]*?>)">
<CFSET Report=StructNew()>
<CFLOOP index="Line" list="#Unscoped#" delimiters="#Chr(10)#">
	<!--- Prep line for parsing --->
	<CFSET CurrLine=REReplace(Line,"(^""|""$)","","ALL")>
	<CFSET CurrLine=REReplace(CurrLine,""",""","|","ALL")>
	<!--- Parse line --->
	<CFSET AppName=ListGetAt(CurrLine,5,"|",true)>
	<CFIF AppName EQ "">
		<CFSET AppName="N/A">
	</CFIF>
	<CFSET ScopeRef=ListGetAt(CurrLine,6,"|",true)>
	<CFIF Mid(ScopeRef,2,1) EQ ":">
		<CFSET FileName=ListGetAt(ScopeRef,1,":") & ":" & ListGetAt(ScopeRef,2,":")>
		<CFSET FileName=Replace(FileName,"\","/","ALL")>
		<CFSET FileName=Replace(RJustify(ListLen(FileName,"/"),5)," ","0","ALL") & "|" & FileName>
		<CFSET ScopeRef=ListDeleteAt(ScopeRef,1,":")>
		<CFSET ScopeRef=ListDeleteAt(ScopeRef,1,":")>
	<CFELSE>
		<CFSET FileName=ListFirst(ScopeRef,":")>
		<CFSET ScopeRef=ListDeleteAt(ScopeRef,1,":")>
	</CFIF>
	<CFIF ListFindNoCase(IgnoreFiles,AppName & "|" & ListLast(FileName,"|"),Chr(10)) EQ 0>
		<CFSET VarName=ListFirst(ScopeRef)>
		<CFIF ListFindNoCase(ScopeList,ListFirst(VarName,".")) EQ 0>
			<CFSET Scope=Replace(ListLast(ScopeRef,":"),"Scope","")>
			<!---<cfoutput>[#Appname#][#FileName#][#scoperef#] - [#VarName#][#Scope#]<br><br></cfoutput>--->
			<!--- Add info to report --->
			<CFIF StructKeyExists(Report,AppName) EQ "NO">
				<CFSET Report[AppName]=StructNew()>
			</CFIF>
			<CFIF StructKeyExists(Report[AppName],FileName) EQ "NO">
				<CFSET Report[AppName][FileName]=StructNew()>
			</CFIF>
			<CFIF StructKeyExists(Report[AppName][FileName],VarName) EQ "NO">
				<CFSET Report[AppName][FileName][VarName]="">
			</CFIF>
			<CFIF ListFindNoCase(Report[AppName][FileName][VarName],Scope) EQ 0>
				<CFSET Report[AppName][FileName][VarName]=ListAppend(Report[AppName][FileName][VarName],Scope)>
			</CFIF>
		</CFIF>
	</CFIF>
</CFLOOP>

<CFSET AppList=ListSort(StructKeyList(Report),"textnocase")>
<CFSET Indent=RepeatString("&nbsp;",4)>
<CFSET HiddenFiles=0>
<CFSET FilesIgnored=ListLen(IgnoreFiles,Chr(10))>
<CFSET Hide=0>

<!--- Display the report --->
<CFOUTPUT>
<!DOCTYPE HTML>
<html>
<head>
<title>Unscoped Variable Report</title>
</head>
<body>
<style type="text/css">
body {font-family:Arial; font-size:12px;}
.Header {font-family:Arial; font-size:24px;}
.TT {font-family:Courier; font-size:12px;white-space: nowrap;}
.Highlight {background:yellow;}
</style>
<span class="Header">Unscoped Variable Report</span><br>
Displaying results from #EncodeForHTML(UnscopeFile)#<br>
<CFIF FilesIgnored GT 0>
	Ignoring #FilesIgnored# file<CFIF FilesIgnored NEQ 1>s</CFIF>
	&nbsp;&nbsp;<a href="?Ignore=Reset">Reset</a><br>
</CFIF>
<div id="HiddenFiles">&nbsp;</div>
<br>
<CFLOOP index="CurrApp" list="#AppList#">
	<big><b>#CurrApp#</b></big>
	<blockquote>
		<CFSET FileList=ListSort(StructKeyList(Report[CurrApp]),"textnocase")>
		<CFLOOP index="CurrFile" list="#FileList#">
			<CFSET UseFile=ListLast(CurrFile,"|")>
			<CFIF Mid(UseFile,2,1) EQ ":" OR Left(UseFile,2) EQ "//">
				<!--- Windows path, reset back to backslash path references --->
				<CFSET UseFile=Replace(UseFile,"/","\","ALL")>
			</CFIF>
			<CFIF OverrideBasePathFrom NEQ "">
				<CFSET UseFile=ReplaceNoCase(UseFile,OverrideBasePathFrom,OverrideBasePathTO)>
			</CFIF>
			<div id="File_#Hash(UseFile)#"><!--- Used to hide the file if no vulnerable lines were found --->
			<CFIF CurrFile NEQ ListFirst(FileList)>
				<br>
			</CFIF>
			<b>#UseFile#</b> &nbsp; <a href="?ignore=#EncodeForURL(CurrApp & "|" & Replace(UseFile,"\","/","ALL"))#">Ignore</a><br>
			<CFIF FileExists(UseFile)>
				<CFFILE action="read" file="#UseFile#" variable="Code">
				<!--- Set EOL to LF & remove tabs --->
				<CFSET Code=Replace(StripCR(Code),Chr(9)," ","ALL")>
				<!--- Identify comment blocks, tried this with RegEx but wasn't able to match a comment block with one or more nested comment blocks as a single group --->
				<CFSET OK=0>
				<CFSET Start=1>
				<CFLOOP condition="NOT OK">
					<CFSET Loc1=Find("<!---",Code,Start)>
					<CFIF Loc1 EQ 0>
						<CFSET OK=1> <!--- No more comment blocks found, flag to exit loop --->
					<CFELSE>
						<!--- Check for nested blocks --->
						<CFSET SubBlockOK=0>
						<CFLOOP condition="NOT SubBlockOK">
							<CFSET Loc2=Find("<!---",Code,Loc1+1)>
							<CFSET Loc3=Find("--->",Code,Loc1+1)>
							<CFIF Loc2 EQ 0 OR Loc3 LT Loc2>
								<CFSET SubBlockOK=1>
							<CFELSE>
								<CFSET Code=Left(Code,Loc2+1) & "x" & Mid(Code,Loc2+2,Len(Code))>
								<!--- Update next close block --->
								<CFSET Loc4=Find("--->",Code,Loc2)>
								<CFIF Loc4 GT 0>
									<!--- Found one, let's change it --->
									<CFSET Code=Left(Code,Loc4+2) & "x" & Mid(Code,Loc4+3,Len(Code))>
								</CFIF>
							</CFIF>
						</CFLOOP>
						<CFSET Start=Loc1+1>
					</CFIF>
				</CFLOOP>
				<!--- Flag all variables scope as unmatchable --->
				<CFSET Code=ReplaceNoCase(Code,"variables.","variables.<x>","ALL")>
				<CFSET VariableList=ListSort(StructKeyList(Report[CurrApp][CurrFile]),"textnocase")>
				<CFSET InCFScript=0>
				<CFSET InCommentBlock=0>
				<CFSET VariablePos1=0>
				<CFSET VariablePos2=0>
				<CFSET EqualPos=0>
				<CFSET ScopeCheck=0>
				<CFSET ScriptSet=0>
				<CFSET ScriptEqual1=0>
				<CFSET ScriptEqual2=0>
				<CFSET Loc5=0>
				<CFSET Loc6="">
				<CFSET CheckPos=0>
				<CFLOOP index="CurrVariable" list="#VariableList#">
					<CFSET DifferentScopeWarning=0>
					<CFSET RepVariable=RepeatString(Chr(3),Len(CurrVariable))>
					<CFIF CurrVariable NEQ ListFirst(VariableList)>
						<br>
					</CFIF>
					#RepeatString("&nbsp;",4)##CurrVariable#: <b>#UCase(Report[CurrApp][CurrFile][CurrVariable])#</b><br>
					<!--- Locate line numbers --->
					<CFSET TotalLC=ListLen(Code,Chr(10),true)>
					<table border="0" cellpadding="0" cellspacing="0">
					<CFLOOP index="LineNo" from="1" to="#TotalLC#">
						<CFSET CurrLine=Trim(ListGetAt(Code,LineNo,Chr(10),true))>
						<CFSET Out=CurrLine>
						<CFIF FindNoCase("<cfscript>",CurrLine)>
							<CFSET InCFScript=1>
						</CFIF>
						<CFIF FindNoCase("<!---",CurrLine) AND FindNoCase("--->",CurrLine) EQ 0>
							<CFSET InCommentBlock=1>
						</CFIF>
						<!--- CF isn't matching everything it should, so let's remove the ( ) for the matching groups and then loop over the | list instead --->
						<CFSET TmpRegEx=Mid(VarRegEx,2,Len(VarRegEx)-2)>
						<CFSET Match=0>
						<CFLOOP index="RegEx" list="#TmpRegEx#" delimiters="|">
							<CFSET UseRegEx=Replace(RegEx,"`",CurrVariable)>
							<!---REFindNoCase("#EncodeForHTML(UseRegEx)#","#EncodeForHTML(CurrLine)#"): #REFindNoCase(UseRegEx,CurrLine)#<br>--->
							<CFSET Match=Match + REFindNoCase(UseRegEx,CurrLine)>
						</CFLOOP>
						<CFIF InCFScript AND REFindNocase("[^\.]#CurrVariable#\s?",CurrLine)>
							<CFSET Match=1>
						</CFIF>
						<CFIF FindNoCase("variables.#CurrVariable#",Out)>
							<CFSET Match=1>
						</CFIF>
						<!---<cfoutput>[#LineNo#][#match#][#InCommentBlock#] #EncodeForHTML(out)#<br></cfoutput>--->
						<CFIF Match GT 0 AND InCommentBlock EQ 0>
						<!--- Highlight variables and check to see if it's an unscoped ColdFusion variable --->
							<CFSET VarMatches=REMatchNoCase("\W#CurrVariable#\W",Out)>
							<CFIF FindNoCase("variables.#CurrVariable#",Out)>
								<CFSET VarMatches[ArrayLen(VarMatches)+1]="variables." & CurrVariable>
							</CFIF>
							<CFLOOP index="i" from="1" to="#ArrayLen(VarMatches)#">
								<!--- Get location of variable --->
								<CFSET Hide=0>
								<CFSET TotalQuotesFound=0>
								<CFSET Loc=Find(VarMatches[i],Out)>
								<CFSET CurrVariable2=Mid(VarMatches[i],2,Len(VarMatches[i]) - 2)> <!--- Current variable in the correct case as used --->
								<CFIF Loc GT 0>
									<!--- Find < character to the left of the variable --->
									<CFSET Start=1>
									<CFSET Loc2=1>
									<CFSET Spot=0>
									<CFLOOP condition="Loc2 EQ 0">
										<CFSET Loc2=Find("<",Out,Start)>
										<CFIF Loc2 GT Loc>
											<CFSET Loc2=0>
										</CFIF>
										<CFIF Loc2 GT 0>
											<CFSET Spot=Loc2>
											<CFSET Start=Loc2 + 1>
										</CFIF>
									</CFLOOP>
									<!--- Check to see if it's a CF tag or not and if it's wrapped in pound characters - hide if not --->
									<CFIF Mid(Out,Loc2 + 1,2) NEQ "CF" AND InCFScript EQ 0 AND REFindNoCase("##[\s\S]*?#CurrVariable#[\s\S]*?##",Out) EQ 0>
										<CFSET Hide=1>
									</CFIF>

									<!--- Check to see if the variable is scoped --->
									<CFSET OK=1>
									<CFSET Loc=FindNoCase(VarMatches[i],Out) + Len(CurrVariable) + 1>
									<CFLOOP index="CurrScope" list="#ScopeList#">
										<CFIF FindNoCase("#CurrScope#.#CurrVariable#",Left(Out,Loc))>
											<CFSET OK=0>
											<CFBREAK>
										</CFIF>
									</CFLOOP>
									<CFIF OK EQ 0>
										<CFSET Hide=2>
									</CFIF>
								</CFIF>
								<!--- If the character to the left of the variable is a period or space but not "variables.", hide it --->
								<CFSET Loc3=FindNoCase(CurrVariable,Out)>
								<CFIF (FindNoCase(".#CurrVariable#",Out) EQ Loc3 - 1 OR FindNoCase("variables.#CurrVariable#",Out) EQ Loc3 - 10) <!--- Hide if period leading or variables scope --->
								  AND (REFindNoCase("\s#CurrVariable#",Out) GT 0 OR FindNoCase("#CurrVariable#",Out) GT 1)> <!--- Don't hide if space or at start of line --->
									<CFSET Hide=3>
								</CFIF>
								<!--- Hide where the variable in question is wrapped in quotes --->
								<CFSET Loc4a=REFindNoCase('"#CurrVariable#"',Out,Loc3 - 1)>
								<CFSET Loc4b=REFindNoCase("'#CurrVariable#'",Out,Loc3 - 1)>
								<CFSET Loc4=Max(Loc4a,Loc4b)>
								<CFIF Loc4 GT 0 AND Mid(Out,Loc2 + 1,7) NEQ "CFPARAM">
									<CFSET Hide=4>
								</CFIF>
								<!--- Check for an inquote string in a cfscript block without #'s --->
								<CFIF InCFScript>
									<!--- Count the number of quote characters prior to the match --->
									<CFSET TotalQuotesFound=0>
									<CFSET Loc5=1>
									<CFSET CheckPos=Loc1>
									<CFLOOP condition="Loc5 GT 0">
										<CFSET Loc5=FindStrBeforePosNoCase(Chr(34),Out,CheckPos)>
										<CFIF Loc5 GT 0>
											<CFSET TotalQuotesFound=TotalQuotesFound + 1>
											<CFSET CheckPos=Loc5 - 1>
										</CFIF>
									</CFLOOP>
									<!--- If count of quotes prior is an odd number, then we are inside a quote block. Check for pound characters around string and if found, hide it --->
									<CFSET Loc5=Mid(Out,Loc3 - 1,1)>
									<CFSET Loc6=Mid(Out,Loc3 + Len(CurrVariable),1)>
									<CFIF Loc5 NEQ "##" OR Loc6 NEQ "##">
										<CFSET Hide=5>
									</CFIF>
								</CFIF>

								<CFIF Hide EQ 0>
									<!--- Highlight --->
									<CFSET Out=ReplaceNoCase(Out,VarMatches[i],Left(VarMatches[i],1) & "[[Highlight]]" &  Mid(VarMatches[i],2,Len(VarMatches[i])-2) & "[[/Highlight]]" & Right(VarMatches[i],1))>
								<CFELSE>
									<!--- Don't highlight --->
									<CFSET Out=ReplaceNoCase(Out,Varmatches[i],Left(VarMatches[i],1) & "<x>#RepVariable#</x>" & Right(VarMatches[i],1))>
								</CFIF>
							</CFLOOP>
							<CFSET LineShown=0>
							<CFIF CurrLine NEQ Replace(Replace(Out,"<x>","","ALL"),"</x>","","ALL")>
								<!--- Replace placeholders with intended value --->
								<CFSET OUt=Replace(Replace(Out,"<x>","","ALL"),"</x>","","ALL")>
								<CFSET Out=Replace(Out,RepVariable,CurrVariable2,"ALL")>
								<CFSET Out=Replace(Out," ","&nbsp;","ALL")>
								<CFSET Out=Replace(Out,"<","&lt;","ALL")>
								<CFIF Find("[[Highlight]]",Out)>
									<!--- Only show the line if something's being highlighted --->
									<CFSET LineShown=1>
								</CFIF>
								<CFSET Out=Replace(Out,"[[Highlight]]","<span class=""Highlight"">","ALL")>
								<CFSET Out=Replace(Out,"[[/Highlight]]","</span>","ALL")>
								<CFIF LineShown>
									<tr>
										<td align="right" class="TT">#Indent##LineNo#:&nbsp;</td>
										<td class="TT">#Out#</td>
									</tr>
								</CFIF>
								<!--- Check for variables scope definition --->
								<CFSET ScriptSet=REFindNoCase("[^\.]#CurrVariable#\s?=",CurrLine)>
								<CFIF ((FindNoCase("<CFSET ",CurrLine)) OR (InCFScript EQ 1 AND ScriptSet GT 0)) AND DifferentScopeWarning EQ 0>
									<CFSET VariablePos1=REFindNoCase("\W#CurrVariable#\W",CurrLine)>
									<CFSET VariablePos2=REFindNoCase("\Wvariables.#CurrVariable#\W",CurrLine)>
									<CFSET ScopeCheck=REFindNoCase("\.#CurrVariable#\W",CurrLine)>
									<CFSET EqualPos=Find("=",CurrLine)>
									<CFSET ScriptEqual1=REFindNoCase("\s#CurrVariable#\s*=",CurrLine)>
									<CFSET ScriptEqual2=REFindNoCase("#CurrVariable#\s*=",CurrLine)>
									<CFIF (VariablePos1 GT 0 AND EqualPos GT 0 AND ScopeCheck EQ 0 AND VariablePos1 LT EqualPos)
									   OR ScriptSet GT 0 OR VariablePos2 GT 0
									   OR (InCFScript EQ 1 AND ScriptEqual1 GT 0)
									   OR (InCFScript EQ 1 AND ScriptEqual2 EQ 1)>
										<CFSET DifferentScopeWarning=1>
										<tr>
											<td></td>
											<td><font color="red">Warning: Variable scope being established</font></td>
										</tr>
									</CFIF>
								</CFIF>
							</CFIF>
						</CFIF>
						<CFIF FindNoCase("</cfscript>",CurrLine)>
							<CFSET InCFScript=0>
						</CFIF>
						<CFIF FindNoCase("--->",CurrLine)>
							<CFSET InCommentBlock=0>
						</CFIF>
					</CFLOOP>
					</table>
				</CFLOOP>
			</CFIF> <!--- Exit file exists check --->
			</div>
			<CFIF LineShown EQ 0>
				<CFSET HiddenFiles=HiddenFiles + 1>
				<script language="JavaScript">
				// Hide previous file block as no vulnerable lines of code were found
				document.getElementById('File_#Hash(UseFile)#').style.display='none';
				</script>
			</CFIF>
		</CFLOOP>
	</blockquote>
</CFLOOP>
<CFIF HiddenFiles GT 0>
	<CFSET Msg=HiddenFiles & " file">
	<CFIF HiddenFiles NEQ 1>
		<CFSET Msg=Msg & "s">
	</CFIF>
	<CFSET Msg=Msg & " were hidden from having no vulnerable lines of code found">
	<script>
	document.getElementById('HiddenFiles').innerHTML='#EncodeForJavascript(Msg)#' + '<br>';
	</script>
</CFIF>
</body>
</html>
</CFOUTPUT>

<CFFUNCTION name="FindStrBeforePosNoCase" hint="Find the last occurance of a string prior to a given location">
	<CFARGUMENT name="SubString" type="String" hint="Substring ot search for">
	<CFARGUMENT name="String" type="String" hint="String to search">
	<CFARGUMENT name="Pos" type="integer" hint="Character position to look before for the Substring">

	<CFSET VAR CurrPos=1>
	<CFSET VAR Done=false>
	<CFSET VAR Loc=0>
	<CFSET VAR FoundLoc=0>

	<CFLOOP condition="NOT Done">
		<CFSET Loc=FindNoCase(Arguments.SubString,Arguments.String,CurrPos)>
		<CFIF Loc GT 0 AND Loc + Len(Arguments.SubString) - 1 LT Arguments.Pos>
			<CFSET FoundLoc=Loc>
			<CFSET CurrPos=Loc + 1>
		<CFELSE>
			<CFSET Done=true>
		</CFIF>
	</CFLOOP>

	<CFRETURN FoundLoc>

</CFFUNCTION>
