# Unscoped.cfm

With ColdFusion removing the scanning of scopes to look for a variable, they released a hotfix that would report on variables that it had to search scopes to locate into a log file.

More information: https://helpx.adobe.com/coldfusion/kb/view-unscoped-variables-log-file.html

The Unscoped.cfm template parses the unscoped.log file created by the hotfix and present it in a readable format, listing each occurance once and then displays code from the file which has variables that still need to be updated.

Example code that uses the unscoped URL.Foo variable but the URL scope is not set.
```
<CFAPPLICATION name="UnscopeTest">

<CFPARAM name="Foo" default="Bar">

<CFOUTPUT>
<!DOCTYPE html>
<html>
<body>
Foo: #FoO#<br>
IsNumeric: #IsNumeric(Foo)#
<form>
Foo: <input type="text" name="Foo" value="#Foo#">
<input type="submit">
</form>
</body>
</html>
</CFOUTPUT>

<!--- <CFSET Moo=Foo> --->
<CFSET Dodad=Foo>
<!---
<!--- Nested comment <CFSET Boo=Foo> --->
<CFSET Zoo=Foo>
--->
<cfscript>
cfparam(name="Too", default="#Foo#", pattern="");
writeoutput("Foo: #Foo#<br>");
</cfscript>

<CFSET Foo=0>
<CFOUTPUT>
Foo: #Foo#<br>
</CFOUTPUT>
```

![Unscope Report](https://www.johnwbartlett.com/GitHub/Unscoped/Unscoped.png)
