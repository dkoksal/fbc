''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2006 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
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


'' symbol table module for variables (scalars and arrays)
''
'' chng: sep/2004 written [v1ctor]
''		 jan/2005 updated to use real linked-lists [v1ctor]

option explicit
option escape

#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\hash.bi"
#include once "inc\list.bi"
#include once "inc\ast.bi"
#include once "inc\rtl.bi"
#include once "inc\emit.bi"

declare function 	hCalcArrayElements	( byval dimensions as integer, _
									  	  dTB() as FBARRAYDIM ) as integer

declare sub 		hDelVarDims			( byval s as FBSYMBOL ptr )

'':::::
sub symbInitDims( ) static

	listNew( @symb.dimlist, FB_INITDIMNODES, len( FBVARDIM ), LIST_FLAGS_NOCLEAR )

end sub


''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' add
''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
function hCreateArrayDesc _
	( _
		byval s as FBSYMBOL ptr, _
		byval dimensions as integer _
	) as FBSYMBOL ptr static

    dim as zstring ptr id, id_alias
    dim as FBSYMBOL ptr d
    dim as integer lgt
    dim as integer isshared, isstatic, isdynamic, iscommon, ispubext

	function = NULL

    '' don't add if it's a jump table
    if( symbIsJumpTb( s ) ) then
    	exit function
    end if

	isshared  = symbIsShared( s )
	isstatic  = symbIsStatic( s )
	isdynamic = symbIsDynamic( s )
	iscommon  = symbIsCommon( s )
	ispubext  = (s->attrib and (FB_SYMBATTRIB_PUBLIC or FB_SYMBATTRIB_EXTERN)) <> 0

	'' COMMON, public or dynamic? use the array name for the descriptor,
	'' as only it will be allocated or seen by other modules
	if( (iscommon) or (ispubext and isdynamic) ) then
		id = s->name
		id_alias = s->alias

	'' otherwise, create a temporary name..
	else
		id = hMakeTmpStr( FALSE )
		id_alias = NULL
	end if

	'' common, shared (also extern) or static? create alias
	if( iscommon or isshared or isstatic ) then
		lgt = 0

	'' local..
	else
		'' dimensions will be unknown if it's a DIM|REDIM array()
		lgt = FB_ARRAYDESCLEN + _
			  iif( dimensions <> INVALID, _
			  	   dimensions, _
			  	   FB_MAXARRAYDIMS ) * FB_ARRAYDESC_DIMLEN
	end if

	d = symbNewSymbol( NULL, _
					   s->symtb, NULL, s->symtb = @symbGetGlobalTb( ), _
					   FB_SYMBCLASS_VAR, _
					   FALSE, id, id_alias, _
					   FB_DATATYPE_USERDEF, cast( FBSYMBOL ptr, FB_DESCTYPE_ARRAY ), 0, _
					   TRUE )
    if( d = NULL ) then
    	exit function
    end if

	''
	if( isshared ) then
		d->attrib or= FB_SYMBATTRIB_SHARED
    end if
	if( isstatic ) then
		d->attrib or= FB_SYMBATTRIB_STATIC
	end if

	d->attrib or= FB_SYMBATTRIB_DESCRIPTOR

	d->lgt = lgt
	d->ofs = 0
	d->stats = s->stats

	d->var.array.desc = NULL
	d->var.array.dif = 0
	d->var.array.dims = 0
	d->var.array.dimhead = NULL
	d->var.array.dimtail = NULL
	d->var.array.elms = 1

    d->var.suffix = INVALID

	''
	function = d

end function

'':::::
function symbNewArrayDim _
	( _
		byval s as FBSYMBOL ptr, _
		byval lower as integer, _
		byval upper as integer _
	) as FBVARDIM ptr static

    dim as FBVARDIM ptr d, n

    function = NULL

    d = listNewNode( @symb.dimlist )
    if( d = NULL ) then
    	exit function
    end if

    d->lower = lower
    d->upper = upper

	n = s->var.array.dimtail
	if( n <> NULL ) then
		n->next = d
	else
		s->var.array.dimhead = d
	end if

	d->next = NULL
	s->var.array.dimtail = d

    function = d

end function

'':::::
sub symbSetArrayDims _
	( _
		byval s as FBSYMBOL ptr, _
		byval dimensions as integer, _
		dTB() as FBARRAYDIM _
	)

    dim as integer i
    dim as FBVARDIM ptr d

	if( dimensions > 0 ) then
		s->var.array.dif = symbCalcArrayDiff( dimensions, dTB(), s->lgt )

		if( (s->var.array.dimhead = NULL) or _
			(s->var.array.dims <> dimensions) ) then

            hDelVarDims( s )

			for i = 0 to dimensions-1
				if( symbNewArrayDim( s, dTB(i).lower, dTB(i).upper ) = NULL ) then
				end if
			next

		else
			d = s->var.array.dimhead
			for i = 0 to dimensions-1
				d->lower = dTB(i).lower
				d->upper = dTB(i).upper
				d = d->next
			next
		end if

		s->var.array.elms = symbCalcArrayElements( s )

	else
		s->var.array.dif = 0
		s->var.array.elms = 1
	end if

	s->var.array.dims = dimensions

	'' dims can be -1 with COMMON arrays..
	if( dimensions <> 0 ) then
		if( s->var.array.desc = NULL ) then
			s->var.array.desc = hCreateArrayDesc( s, dimensions )
		end if
	else
		s->var.array.desc = NULL
	end if

end sub

'':::::
private sub hSetupVar _
	( _
		byval s as FBSYMBOL ptr, _
		byval id as zstring ptr, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval lgt as integer, _
		byval dimensions as integer, _
		dTB() as FBARRAYDIM, _
		byval attrib as integer, _
		byval stats as integer _
	) static

	if( dtype = INVALID ) then
		dtype = hGetDefType( id )
	end if

	''
	s->attrib or= attrib
	s->stats or= stats

	s->lgt = lgt
	s->ofs = 0

	'' array fields
	s->var.array.dimhead = NULL
	s->var.array.dimtail = NULL
	s->var.array.desc = NULL

	if( dimensions <> 0 ) then
		symbSetArrayDims( s, dimensions, dTB() )
	else
		s->var.array.dims = 0
		s->var.array.dif = 0
		s->var.array.elms = 1
	end if

	s->var.initree = NULL

	s->var.stmtnum = env.stmtcnt

end sub

'':::::
function symbAddVarEx _
	( _
		byval id as zstring ptr, _
		byval id_alias as zstring ptr, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval ptrcnt as integer, _
		byval lgt as integer, _
		byval dimensions as integer, _
		dTB() as FBARRAYDIM, _
		byval attrib as integer, _
		byval addsuffix as integer, _
		byval preservecase as integer _
	) as FBSYMBOL ptr static

    dim as FBSYMBOL ptr s
    dim as FBSYMBOLTB ptr symtb
    dim as FBHASHTB ptr hashtb
    dim as integer isglobal, suffix, stats

    function = NULL

    ''
    isglobal = (attrib and (FB_SYMBATTRIB_PUBLIC or _
			 				FB_SYMBATTRIB_EXTERN or _
			 				FB_SYMBATTRIB_SHARED)) <> 0

	'' inside a namespace but outside a proc?
	if( symbIsGlobalNamespc() = FALSE ) then
		if( fbIsModLevel( ) ) then
			'' they are never allocated on stack..
			attrib or= FB_SYMBATTRIB_STATIC
		end if
	end if

    ''
    if( lgt <= 0 ) then
		if( dtype = INVALID ) then
			suffix = hGetDefType( id )
		else
			suffix = dtype
 		end if
    	lgt	= symbCalcLen( suffix, subtype )
    end if

    ''
    if( addsuffix ) then
    	suffix = dtype
    else
    	suffix = INVALID
    end if

    '' no explict alias?
    if( id_alias = NULL ) then
    	'' only preserve a case-sensitive version if in BASIC mangling
    	if( env.mangling <> FB_MANGLING_BASIC ) then
    		id_alias = id
    	end if
    	stats = 0

    else
		stats = FB_SYMBSTATS_HASALIAS
	end if

	'' local? add to local symb & hash tbs
	if( isglobal = FALSE ) then
		symtb = symb.symtb
		hashtb = symb.hashtb

		'' can't add local static vars to global list because
		'' symbDelSymbolTb() will miss them when flushing the
		'' proc/scope block, and also because the the dbg info

	'' global..
	else
		'' inside a namespace and not a literal-constant?
		if( (symbIsGlobalNamespc( ) = FALSE) and _
			((attrib and FB_SYMBATTRIB_LITCONST) = 0) ) then

			symtb = @symbGetNamespaceTb( symb.namespc )
			hashtb = @symbGetNamespaceHashTb( symb.namespc )

		'' module-level..
		else
			symtb = @symbGetGlobalTb( )
			hashtb = @symbGetGlobalHashTb( )
		end if
	end if

	s = symbNewSymbol( NULL, _
					   symtb, hashtb, isglobal, _
					   FB_SYMBCLASS_VAR, _
					   TRUE, id, id_alias, _
					   dtype, subtype, ptrcnt, _
					   preservecase, suffix )

	if( s = NULL ) then
		exit function
	end if

	''
	hSetupVar( s, id, dtype, subtype, lgt, dimensions, dTB(), attrib, stats )

	function = s

end function

'':::::
function symbAddVar _
	( _
		byval symbol as zstring ptr, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval ptrcnt as integer, _
		byval dimensions as integer, _
		dTB() as FBARRAYDIM, _
		byval attrib as integer _
	) as FBSYMBOL ptr static

    function = symbAddVarEx( symbol, NULL, dtype, subtype, ptrcnt, _
    		  			     0, dimensions, dTB(), _
    						 attrib, _
    						 TRUE, FALSE )
end function

'':::::
function symbAddTempVar _
	( _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr = NULL, _
		byval doalloc as integer = FALSE, _
		byval checkstatic as integer = TRUE _
	) as FBSYMBOL ptr static

	static as zstring * FB_MAXNAMELEN+1 id
	dim as integer attrib
    dim as FBSYMBOL ptr s
    dim as FBARRAYDIM dTB(0)

	id = *hMakeTmpStr( FALSE )

	attrib = FB_SYMBATTRIB_TEMP
	if( checkstatic ) then
		if( fbIsModLevel( ) = FALSE ) then
			if( env.isprocstatic ) then
				attrib or= FB_SYMBATTRIB_STATIC
			end if
		end if
	end if

	s = symbAddVarEx( id, NULL, dtype, subtype, 0, _
					  0, 0, dTB(), _
					  attrib, _
					  FALSE, FALSE )
    if( s = NULL ) then
    	return NULL
    end if

	'' alloc? (should be used only by IR)
	if( doalloc ) then
    	'' not shared, static or a parameter?
    	if( (s->attrib and (FB_SYMBATTRIB_SHARED or _
    		 			   	FB_SYMBATTRIB_STATIC or _
    		 			   	FB_SYMBATTRIB_COMMON or _
							FB_SYMBATTRIB_PARAMBYDESC or _
    			  			FB_SYMBATTRIB_PARAMBYVAL or _
    			  			FB_SYMBATTRIB_PARAMBYREF)) = 0 ) then

			s->ofs = emitAllocLocal( env.currproc, s->lgt )

		end if
	end if

    function = s

end function

''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' misc
''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
function symbCalcArrayDiff _
	( _
		byval dimensions as integer, _
		dTB() as FBARRAYDIM, _
		byval lgt as integer _
	) as integer

    dim as integer d, diff, elms, mult

	if( dimensions <= 0 ) then
		return 0
	end if

	diff = 0
	for d = 0 to (dimensions-1)-1
		elms = (dTB(d+1).upper - dTB(d+1).lower) + 1
		diff = (diff+dTB(d).lower) * elms
	next

	diff += dTB(dimensions-1).lower

	diff *= lgt

	function = -diff

end function

'':::::
function symbCalcArrayElements _
	( _
		byval s as FBSYMBOL ptr, _
		byval n as FBVARDIM ptr = NULL _
	) as integer static

    dim as integer e, d

	if( n = NULL ) then
		n = s->var.array.dimhead
	end if

	e = 1
	do while( n <> NULL )
		d = (n->upper - n->lower) + 1
		e = e * d
		n = n->next
	loop

	function = e

end function

'':::::
private function hCalcArrayElements _
	( _
		byval dimensions as integer, _
		dTB() as FBARRAYDIM _
	) as integer static

    dim as integer e, i, d

	e = 1
	for i = 0 to dimensions-1
		d = (dTB(i).upper - dTB(i).lower) + 1
		e = e * d
	next i

	function = e

end function

'':::::
function symbVarIsLocalDyn _
	( _
		byval s as FBSYMBOL ptr _
	) as integer static

    function = FALSE

    '' shared, static, param or temp?
    if( (s->attrib and (FB_SYMBATTRIB_SHARED or _
    					FB_SYMBATTRIB_STATIC or _
    					FB_SYMBATTRIB_COMMON or _
    					FB_SYMBATTRIB_PARAMBYDESC or _
    		  			FB_SYMBATTRIB_PARAMBYVAL or _
    		  			FB_SYMBATTRIB_PARAMBYREF or _
    		  			FB_SYMBATTRIB_TEMP or _
    		  			FB_SYMBATTRIB_FUNCRESULT)) <> 0 ) then
		exit function
	end if

	'' dyn string?
	if( s->typ = FB_DATATYPE_STRING ) then
		function = TRUE

	'' array? dims can be -1 with "DIM foo()" arrays..
	elseif( s->var.array.dims <> 0 ) then
		'' dynamic?
		function = symbIsDynamic( s )
	end if

end function

'':::::
function symbVarIsLocalObj _
	( _
		byval s as FBSYMBOL ptr _
	) as integer static

    '' shared, static, param or temp?
    if( (s->attrib and (FB_SYMBATTRIB_SHARED or _
    					FB_SYMBATTRIB_STATIC or _
    					FB_SYMBATTRIB_COMMON or _
    					FB_SYMBATTRIB_PARAMBYDESC or _
    		  			FB_SYMBATTRIB_PARAMBYVAL or _
    		  			FB_SYMBATTRIB_PARAMBYREF or _
    		  			FB_SYMBATTRIB_TEMP or _
    		  			FB_SYMBATTRIB_FUNCRESULT)) <> 0 ) then

		return FALSE
	end if

	'' notes:
	'' 1) it doesn't matter if it's dynamic array or not, local non-dynamic
	''	  array allocations will do calls to ArraySetDesc, so arrays can't
	''	  be accessed before that
	''
	'' 2) dynamic strings aren't taken as objects, descriptors are always
	''    cleared when entering scopes (including procs)

	'' array? dims can be -1 with "DIM foo()" arrays..
	function = (s->var.array.dims <> 0)

end function

''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' del
''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
private sub hDelVarDims _
	( _
		byval s as FBSYMBOL ptr _
	) static

    dim as FBVARDIM ptr n, nxt

    n = s->var.array.dimhead
    do while( n <> NULL )
    	nxt = n->next

    	listDelNode( @symb.dimlist, n )

    	n = nxt
    loop

    s->var.array.dimhead = NULL
    s->var.array.dimtail = NULL
    s->var.array.dims	  = 0

end sub

'':::::
sub symbDelVar _
	( _
		byval s as FBSYMBOL ptr _
	)

    dim as integer movetoglob

    if( s = NULL ) then
    	exit sub
    end if

	movetoglob = FALSE

	'' local and static? move to global sym tb (see symbAddVarEx())
	if( symbIsLocal( s ) ) then
    	if( symbIsStatic( s ) ) then
    		if( s->symtb <> @symbGetGlobalTb( ) ) then
    			movetoglob = TRUE
    		end if
    	end if
	end if

	if( movetoglob = FALSE ) then
    	if( s->var.array.dims > 0 ) then
    		hDelVarDims( s )
    		'' del the array descriptor, recursively
    		symbDelVar( s->var.array.desc )
    	end if

    	if( symbGetIsLiteral( s ) ) then
    		s->attrib and= not FB_SYMBATTRIB_LITERAL

    		'' not a wchar literal?
    		if( s->typ <> FB_DATATYPE_WCHAR ) then
    			if( s->var.littext <> NULL ) then
    				ZstrFree( s->var.littext )
    			end if
    		else
    			if( s->var.littextw <> NULL ) then
    				WstrFree( s->var.littextw )
    			end if
    		end if

    	''
    	elseif( symbGetIsInitialized( s ) ) then
    		s->stats and= not FB_SYMBSTATS_INITIALIZED
    		'' astEnd will free the nodes..
    	end if

    end if

    ''
    symbFreeSymbol( s, movetoglob )

end sub

'':::::
function symbFreeDynVar _
	( _
		byval s as FBSYMBOL ptr _
	) as ASTNODE ptr

	'' assuming conditions were checked already

	'' array? dims can be -1 with "DIM foo()" arrays..
	if( s->var.array.dims <> 0 ) then
		'' dynamic?
		if( symbIsDynamic( s ) ) then
			function = rtlArrayErase( astNewVAR( s, 0, s->typ ) )

		'' array of dyn strings?
		elseif( s->typ = FB_DATATYPE_STRING ) then
			function = rtlArrayStrErase( s )
		end if

	'' dyn string?
	elseif( s->typ = FB_DATATYPE_STRING ) then
		function = rtlStrDelete( astNewVAR( s, 0, FB_DATATYPE_STRING ) )
	end if

end function
'':::::
sub symbFreeLocalDynVars _
	( _
		byval proc as FBSYMBOL ptr _
	) static

    dim as FBSYMBOL ptr s

	s = symb.symtb->head
    do while( s <> NULL )
    	'' variable?
    	if( s->class = FB_SYMBCLASS_VAR ) then
    		'' not shared, static, param or temp?
    		if( (s->attrib and (FB_SYMBATTRIB_SHARED or _
    							FB_SYMBATTRIB_STATIC or _
    							FB_SYMBATTRIB_COMMON or _
    							FB_SYMBATTRIB_PARAMBYDESC or _
    				  			FB_SYMBATTRIB_PARAMBYVAL or _
    				  			FB_SYMBATTRIB_PARAMBYREF or _
    				  			FB_SYMBATTRIB_TEMP or _
    				  			FB_SYMBATTRIB_FUNCRESULT)) = 0 ) then

				astAdd( symbFreeDynVar( s ) )

			end if
    	end if

    	s = s->next
    loop

end sub



