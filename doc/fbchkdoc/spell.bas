''  fbchkdoc - FreeBASIC Wiki Management Tools
''	Copyright (C) 2008 Jeffery R. Marshall (coder[at]execulink[dot]com)
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.

'' spell.bas - spell check the entire wiki

'' chng: written [jeffm]

'' fbdoc headers
#include once "CWiki.bi"
#include once "CWikiCache.bi"
#include once "CRegex.bi"
#include once "list.bi"
#include once "hash.bi"
#include once "fbdoc_defs.bi"
#include once "fbdoc_keywords.bi"
#include once "COptions.bi"

'' fbchkdoc headers
#include once "fbchkdoc.bi"
#include once "funcs.bi"
#include once "spellcheck.bi"

'' libs
#inclib "pcre"
#inclib "curl"

using fb
using fbdoc

const Letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const Numbers = "0123456789"

dim shared pagehash as HASH
dim shared wordhash as HASH
dim shared CurrentPage as string
dim shared haveTitle as integer
dim shared counter as integer

''
function IsKeyword( byref word as string ) as integer
	dim kw as string
	kw = fbdoc_findkeyword( word )
	if( kw > "" ) then
		function = TRUE
	else
		function = FALSE
	end if
end function

''
function IsWikiPage( byref word as string ) as integer
	if( pagehash.test( word ) ) then
		function = TRUE
	else
		function = FALSE
	end if
end function

''
function IsDictWord( byref word as string ) as integer
	if( wordhash.test( word ) ) then
		function = TRUE
	else
		function = FALSE
	end if
end function

''
function IsVariable( byref word as string ) as integer
	if( instr( word, "_" ) > 0 ) then
		function = TRUE
	else
		function = FALSE
	end if
end function

''
function IsUrl( byref word as string ) as integer
	if( lcase(left( word, 7 )) = "http://" ) then
		function = TRUE
	else
		function = FALSE
	end if
end function

''
function GetWord( byref text as string, byref i as integer, byref j as integer ) as string
	
	function = ""

	if( i <= len(text) ) then
	
		while( i <= len(text) )
			if( instr( letters + "_", mid( text, i , 1 )) = 0 ) then
				i += 1
			else
				exit while
			end if
		wend

		j = i
		while( i <= len(text) )
			if( instr( numbers + letters + "'_", mid( text, i , 1 )) <> 0 ) then
				i += 1
			else
				exit while
			end if
		wend

		if( j <= len(text) ) then
			if( lcase(mid( text, j, i - j + 1 )) = "http:" ) then
				while( i <= len(text) )
					if( instr( numbers + letters + ":.%/" + "_", mid( text, i , 1 )) <> 0 ) then
						i += 1
					else
						exit while
					end if
				wend
			end if
		end if

		if( j <= len( text ) ) then
			select case mid( text, i - 1, 1 )
			case "'"
				function = mid( text, j, i - j - 1 )
			case else
				function = mid( text, j, i - j )
			end select
		end if

		j = i

	end if

end function

''
function DoSpellCheckWord( byref word as string ) as integer

	if( SpellCheck_WordCorrect(word) = TRUE ) then
		function = TRUE
	elseif( IsKeyword( word ) ) then
		function = TRUE
	elseif( IsWikiPage( word ) ) then
		function = TRUE
	elseif( IsDictWord( word ) ) then
		function = TRUE
	elseif( IsVariable( word ) ) then
		function = TRUE
	elseif( IsUrl( word ) ) then
		function = TRUE
	else
		if( haveTitle = FALSE ) then
			print
			print CurrentPage
			haveTitle = TRUE
		end if
		print , word
		function = FALSE
	end if

end function

''
function DoSpellCheck( byref text as string ) as integer

	dim w as string
	dim as integer i = 1, j
	
	w = GetWord( text, i, j )
	while( w > "" )
		DoSpellCheckWord( w )
		w = GetWord( text, i, j )
	wend

	function = FALSE

end function

''
function DoWordCount( byref text as string ) as integer

	dim w as string
	dim as integer i = 1, j

	w = GetWord( text, i, j )
	while( w > "" )
		counter += 1
		w = GetWord( text, i, j )
	wend

	function = counter

end function

''
function DoSpellCheckPage _
	( _
		byval _this as CWiki ptr, _
		byref sPageName as string, _
		byval h as integer _
	) as integer
	
	dim as WikiToken ptr token
	dim as string t, text, sUrl, sLink

	dim as integer TT = 0
	
	dim as integer f = freefile, n = 0, bInExamples = FALSE

	function = FALSE

	token = _this->GetTokenList()->GetHead()
	do while( token <> NULL )
		text = token->text

		select case as const token->id
		case WIKI_TOKEN_LT
			t = "<"
		case WIKI_TOKEN_GT
			t = ">"
		case WIKI_TOKEN_BOXLEFT
			t = "<<"
		case WIKI_TOKEN_BOXRIGHT
			t = ">>"
		case WIKI_TOKEN_CLEAR
			t = "::c::"
		case WIKI_TOKEN_KBD
			t = "#%"
		case WIKI_TOKEN_BOLD
			t = "**"
		case WIKI_TOKEN_BOLD_SECTION
			t = "=="
		case WIKI_TOKEN_ITALIC
			t = "//"
		case WIKI_TOKEN_UNDERLINE
			t = "__"
		case WIKI_TOKEN_MONOSPACE
			t = "##"
			tt = 1 - tt
		case WIKI_TOKEN_NOTES
			t = "''"
		case WIKI_TOKEN_STRIKE
			t = "++"
		case WIKI_TOKEN_CENTER
			t = "@@"
		case WIKI_TOKEN_HEADER
			t = string( token->header->level, "=" )
		case WIKI_TOKEN_NEWLINE
			t = chr(10)
		case WIKI_TOKEN_CODE
			t = "%%(" + token->code->lang + ")"
			t += token->text
			t += "%%"

			DoWordCount( token->text )

		case WIKI_TOKEN_PRE
			t = "%%"
			t += token->text
			t += "%%"

			'' DoSpellCheck( token->text )
			DoWordCount( token->text )

		case WIKI_TOKEN_LINK
			if( token->text > "" ) then
				t = "[[" + token->link->url + " " + token->text + "]]"
			else
				t = "[[" + token->link->url + "]]"
			end if

			counter += 1

		case WIKI_TOKEN_ACTION

			dim as WikiAction_Param ptr param, nxt
			dim as string tmp
			dim as integer i

			t = "{{" + token->action->name

			param = token->action->paramhead
			dim as integer p = 1
			do while( param <> NULL )
				i = instr( param->value, chr(34) )
				if( i > 0 ) then
					tmp = param->value
					DoWordCount( tmp )
					do
						tmp = left( tmp, i - 1) & "&quot" & mid( tmp, i + 1 )
						i = instr(i + 5, tmp, chr(34) )
					loop while ( i > 0 )
					t += " " + param->name + "=""" + tmp + """"
				else
					t += " " + param->name + "=""" + param->value + """"
				end if
				param = param->next
				p += 1
			loop

			t += "}}"
			
		case WIKI_TOKEN_INDENT
			'' t = string( token->indent->level, 9 ) + token->indent->bullet
			t = token->indent->indent + token->indent->bullet
		case WIKI_TOKEN_LIST
			'' t = string( token->indent->level, 9 ) + token->indent->bullet
			t = token->indent->indent + token->indent->bullet
		case WIKI_TOKEN_TEXT
			t = token->text
			DoWordCount( token->text )
			if( tt = 0 ) then
				DoSpellCheck( token->text )
			end if
		case WIKI_TOKEN_RAW
			t = """""" + token->text + """"""
			if( tt = 0 ) then
				DoSpellCheck( token->text )
			end if
		case WIKI_TOKEN_FORCENL
			t = "---"
		case WIKI_TOKEN_HORZLINE
			t = "----"
		end select
		
		token = _this->GetTokenList()->GetNext( token )
	loop
	
end function

'' --------------------------------------------------------
'' MAIN
'' --------------------------------------------------------

dim as string cache_dir, def_cache_dir, web_cache_dir, dev_cache_dir

dim as integer i = 1, webPageCount = 0
redim webPageList(1 to 1) as string
dim as string cmt

if( command(i) = "" ) then
	print "spell [pages] [@pagelist] [options]"
	print
	print "   pages      list of wiki pages on the command line"
	print "   @pagelist	 text file with a list of pages, one per line"
	print
	print "   -web       spellcheck files in cache_dir"
	print "   -web+      spellcheck files in web cache_dir"
	print "   -dev       spellcheck files in cache_dir"
	print "   -dev+      spellcheck files in dev cache_dir"
	end 0
end if

'' read defaults from the configuration file (if it exists)
scope
	dim as COptions ptr opts = new COptions( default_optFile )
	if( opts <> NULL ) then
		def_cache_dir = opts->Get( "cache_dir", default_CacheDir )
		web_cache_dir = opts->Get( "web_cache_dir", default_web_CacheDir )
		dev_cache_dir = opts->Get( "dev_cache_dir", default_dev_CacheDir )
		delete opts
	else
		'' print "Warning: unable to load options file '" + default_optFile + "'"
		'' end 1
		def_cache_dir = default_CacheDir
		web_cache_dir = default_web_CacheDir
		dev_cache_dir = default_dev_CacheDir
	end if
end scope

while command(i) > ""
	if( left(command(i), 1) = "-" ) then
		select case lcase(command(i))
		case "-web", "-dev"
			cache_dir = def_cache_dir
		case "-web+"
			cache_dir = web_cache_dir
		case "-dev+"
			cache_dir = dev_cache_dir
		case else
			print "Unrecognized option '" + command(i) + "'"
			end 1
		end select
	else
		if left( command(i), 1) = "@" then
			scope
				dim h as integer, x as string
				h = freefile
				if open( mid(command(i),2) for input access read as #h ) <> 0 then
					print "Error reading '" + command(i) + "'"
				else
					while eof(h) = 0
						line input #h, x
						x = ParsePageName( x, cmt )
						if( x > "" ) then 
							webPageCount += 1
							if( webPageCount > ubound(webPageList) ) then
								redim preserve webPageList(1 to Ubound(webPageList) * 2)
							end if
							webPageList(webPageCount) = x
						end if
					wend
					close #h
				end if
			end scope
		else
			webPageCount += 1
			if( webPageCount > ubound(webPageList) ) then
				redim preserve webPageList(1 to Ubound(webPageList) * 2)
			end if
			webPageList(webPageCount) = command(i)		
		end if
	end if
	i += 1
wend

if( webPageCount = 0 ) then
	print "no pages specified."
	end 1
end if

dim as CWikiCache ptr wikicache
dim as string sPage, sBody

if( cache_dir = "" ) then
	cache_dir = default_CacheDir
end if
print "cache: "; cache_dir

'' Initialize the cache
wikicache = new CWikiCache( cache_dir, CWikiCache.CACHE_REFRESH_NONE )
if wikicache = NULL then
	print "Unable to use local cache dir " + cache_dir
	end 1
end if

if( webPageCount > 0 ) then
	dim as integer i, h, h2
	dim as string ret

	pagehash.alloc( 1000 )
	wordhash.alloc( 1000 )

	scope
		dim as string x, cmt
		h = freefile
		if( open( "PageIndex.txt" for input as #h ) = 0 ) then
			while eof( h ) = 0
				line input #h, x
				x = ParsePageName( x, cmt )
				if( x > "" ) then
					pagehash.add x
				end if
			wend
			close #h
		end if
	end scope

	scope
		dim as string x, cmt
		h = freefile
		if( open( "dict.txt" for input as #h ) = 0 ) then
			while eof( h ) = 0
				line input #h, x
				x = trim(x)
				if( x > "" ) then
					wordhash.add x
				end if
			wend
			close #h
		end if
	end scope

	fb.fbdoc.fbdoc_loadkeywords( "../manual/templates/default/keywords.lst" )
	SpellCheck_Init( "en_US" )

''	h = freefile
''	open "spellcheck.txt" for output as #h

	for i = 1 to webPageCount

		sPage = webPageList(i)

		CurrentPage = sPage
		haveTitle = FALSE

		'' ignore some pages
		if( left(lcase(sPage), 3) <> "ext" ) then
		if( left(lcase(sPage), 3) <> "faq" ) then
		if( left(lcase(sPage), 3) <> "tut" ) then
		if( left(lcase(sPage), 3) <> "svn" ) then
		if( left(lcase(sPage), 3) <> "cvs" ) then
		if( left(lcase(sPage), 4) <> "wiki" ) then
		if( left(lcase(sPage), 7) <> "license" ) then

		if( wikicache->LoadPage( sPage, sBody ) ) = FALSE then
			print
			print sPage
			print , "Unable to load"

		else

			dim as CWiki Ptr wiki
			wiki = new CWiki

			wiki->Parse( sPage, sBody )

			if( DoSpellCheckPage( wiki, sPage, h ) ) then
				''
			end if

			delete wiki

		end if

		endif
		endif
		endif
		endif
		endif
		endif
		endif

	next

	print
	print "WORD COUNT = "; counter

''	close #h

	SpellCheck_Exit()
	
	end 0
end if

end 0
