''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2007 The FreeBASIC development team.
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


'' symbol type (BYTE, INTEGER, STRING, ...) declarations
''
'' chng: sep/2004 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\parser.bi"
#include once "inc\ast.bi"
#include once "inc\rtl.bi"

''::::
function cConstExprValue _
	( _
		byref value as integer _
	) as integer

    dim as ASTNODE ptr expr

    function = FALSE

    expr = cExpression( )
    if( expr = NULL ) then
    	if( errReport( FB_ERRMSG_EXPECTEDEXPRESSION ) = FALSE ) then
    		exit function
    	else
    		'' error recovery: fake an value
    		value = 0
    		return TRUE
    	end if

	else
		if( astIsCONST( expr ) = FALSE ) then
			if( errReport( FB_ERRMSG_EXPECTEDCONST ) = FALSE ) then
				exit function
    		else
    			'' error recovery: fake an value
    			astDelTree( expr )
    			value = 0
    			return TRUE
			end if
		end if
    end if

	value = astGetValueAsInt( expr )
  	astDelNode( expr )

  	function = TRUE

end function

'':::::
function cSymbolTypeFuncPtr _
	( _
		byval isfunction as integer _
	) as FBSYMBOL ptr

	dim as integer dtype, lgt, mode, ptrcnt
	dim as FBSYMBOL ptr proc, subtype

	function = NULL

	'' mode
	mode = cProcCallingConv( )

	proc = symbPreAddProc( NULL )

	'' Parameters?
	if( cParameters( NULL, proc, mode, TRUE ) = NULL ) then
		if( errGetLast( ) <> FB_ERRMSG_OK ) then
			exit function
		end if
	end if

	'' (AS SymbolType)?
	if( lexGetToken( ) = FB_TK_AS ) then
		lexSkipToken( )

		if( cSymbolType( dtype, subtype, lgt, ptrcnt ) = FALSE ) then
			if( errReport( FB_ERRMSG_EXPECTEDIDENTIFIER ) = FALSE ) then
				exit function
			else
				'' error recovery: fake a type
				dtype = FB_DATATYPE_INTEGER
				subtype = NULL
				ptrcnt = 0
			end if
		end if

    	'' check for invalid types
    	select case as const dtype
    	case FB_DATATYPE_FIXSTR, FB_DATATYPE_CHAR, FB_DATATYPE_WCHAR
    		if( errReport( FB_ERRMSG_CANNOTRETURNFIXLENFROMFUNCTS ) = FALSE ) then
    			exit function
			else
				'' error recovery: fake a type
				dtype = FB_DATATYPE_INTEGER
				subtype = NULL
				ptrcnt = 0
			end if

    	case FB_DATATYPE_VOID
    		if( errReport( FB_ERRMSG_INVALIDDATATYPES ) = FALSE ) then
    			exit function
			else
				'' error recovery: fake a type
				dtype += FB_DATATYPE_POINTER
				subtype = NULL
				ptrcnt = 1
			end if
    	end select

	else
		'' if it's a function and type was not given, it can't be guessed
		if( isfunction ) then
			if( errReport( FB_ERRMSG_EXPECTEDRESTYPE ) = FALSE ) then
				exit function
			else
				'' error recovery: fake a type
				dtype = FB_DATATYPE_INTEGER
				subtype = NULL
				ptrcnt = 0
			end if

		else
			dtype = FB_DATATYPE_VOID
			subtype = NULL
			ptrcnt = 0
		end if
	end if

	function = symbAddProcPtr( proc, dtype, subtype, ptrcnt, mode )

end function


'':::::
function cTypeOf _
	( _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr, _
		byref lgt as integer = NULL, _
		byref ptrcnt as integer = NULL _
	) as integer
    
    function = FALSE
    
	dim as ASTNODE ptr expr = NULL

	'' is it a normal type?
	if( cSymbolType( dtype, subtype, lgt, ptrcnt, FB_SYMBTYPEOPT_NONE ) = FALSE ) then
		fbSetCheckArray( FALSE )
        
		expr = cExpression( )
		if( expr = NULL ) then
			fbSetCheckArray( TRUE )
			if( errReport( FB_ERRMSG_EXPECTEDEXPRESSION ) = FALSE ) then
				exit function
			else
				'' error recovery: fake an expr
				expr = astNewCONSTi( 0, FB_DATATYPE_INTEGER )
			end if

		end if

		fbSetCheckArray( TRUE )
	else
		'' everything okay
		return TRUE
	end if

    if( astIsCONST( expr ) ) then
		lgt     = rtlCalcExprLen( expr, FALSE )
		dtype   = astGetDataType( expr ) 
		subtype = astGetSubType( expr )
		ptrcnt  = 0 '' <-- pointer constants?

	else
		'' ugly hack to deal with arrays w/o indexes
		if( astIsNIDXARRAY( expr ) ) then
			dim as ASTNODE ptr temp_node = expr
			expr = astGetLeft( expr )
			astDelNode( temp_node )
		end if
	    
		dim as integer derefs = 0
		dim as ASTNODE ptr walk = expr
		dim as FBSYMBOL ptr sym = astGetSymbol( expr )
		if( sym = NULL ) then
			dtype   = astGetDataType( expr )
			subtype = astGetSubtype( expr )
		else
			while walk
				'' if it's a field, get this node's type, 
				'' don't "solve" the tree
				if( astGetClass( walk ) = AST_NODECLASS_FIELD ) then
					sym = astGetSymbol( walk )
					exit while
				end if 
		
				'' count derefs
				if( astGetClass( walk ) = AST_NODECLASS_DEREF ) then
					derefs += 1
				end if
		
				'' update/walk
				sym = astGetSymbol( walk )
				walk = astGetLeft( walk )
			wend
			lgt     = symbGetLen( sym )
			dtype   = symbGetType( sym )
			subtype = symbGetSubtype( sym )
			ptrcnt  = symbGetPtrCnt( sym )
		end if

		'' byref args have a deref, 
		'' but they maintain their type
		if( typeIsPOINTER( dtype ) ) then
			if( derefs > 0 ) then
				'' balance it
				dtype  -= (FB_DATATYPE_POINTER * derefs)
				ptrcnt -= (derefs)
			end if
		end if
	
	end if
	
	astDelTree( expr )
	
	function = TRUE

end function

'':::::
''SymbolType      =   UNSIGNED? (
''				      ANY
''				  |   CHAR|BYTE
''				  |	  SHORT|WORD
''				  |	  INTEGER|LONG|DWORD
''				  |   SINGLE
''				  |   DOUBLE
''                |   STRING ('*' NUM_LIT)?
''                |   USERDEFTYPE
''				  |   (FUNCTION|SUB) ('(' args ')') (AS SymbolType)?
''				      (PTR|POINTER)* .
''
function cSymbolType _
	( _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr, _
		byref lgt as integer, _
		byref ptrcnt as integer, _
		byval options as FB_SYMBTYPEOPT _
	) as integer

    dim as integer isunsigned = any, isfunction = any

	function = FALSE

	lgt = 0
	dtype = INVALID
	subtype = NULL
	ptrcnt = 0
	
	'' TYPEOF?
	if( hMatch( FB_TK_TYPEOF ) ) then
	    '' '('
  		if( hMatch( CHAR_LPRNT ) = FALSE ) then
  			if( errReport( FB_ERRMSG_EXPECTEDLPRNT ) = FALSE ) then
  				exit function
  			else
  				'' error recovery: skip until ')'
  				hSkipUntil( CHAR_RPRNT, TRUE )
  			end if
  		end if
  		'' datatype
        if( cTypeOf( dtype, subtype, lgt, ptrcnt ) = FALSE ) then
        	return FALSE 
        end if
	    '' ')'
		if( hMatch( CHAR_RPRNT ) = FALSE ) then
			if( errReport( FB_ERRMSG_EXPECTEDRPRNT ) = FALSE ) then
				exit function
			else
				'' error recovery: skip until ')'
				hSkipUntil( CHAR_RPRNT, TRUE )
			end if
		end if
	
	else
	
		'' UNSIGNED?
		isunsigned = hMatch( FB_TK_UNSIGNED )
	
		''
		select case as const lexGetToken( )
		case FB_TK_ANY
			lexSkipToken( )
			dtype = FB_DATATYPE_VOID
			lgt = 0
	
		case FB_TK_BYTE
			lexSkipToken( )
			dtype = FB_DATATYPE_BYTE
			lgt = 1
		case FB_TK_UBYTE
			lexSkipToken( )
			dtype = FB_DATATYPE_UBYTE
			lgt = 1
	
		case FB_TK_SHORT
			lexSkipToken( )
			dtype = FB_DATATYPE_SHORT
			lgt = 2
	
		case FB_TK_USHORT
			lexSkipToken( )
			dtype = FB_DATATYPE_USHORT
			lgt = 2
	
		case FB_TK_INTEGER
			lexSkipToken( )
			dtype = FB_DATATYPE_INTEGER
			lgt = FB_INTEGERSIZE
	
		case FB_TK_UINT
			lexSkipToken( )
			dtype = FB_DATATYPE_UINT
			lgt = FB_INTEGERSIZE
	
		case FB_TK_LONG
			lexSkipToken( )
			dtype = FB_DATATYPE_LONG
			lgt = FB_LONGSIZE
	
		case FB_TK_ULONG
			lexSkipToken( )
			dtype = FB_DATATYPE_ULONG
			lgt = FB_LONGSIZE
	
		case FB_TK_LONGINT
			lexSkipToken( )
			dtype = FB_DATATYPE_LONGINT
			lgt = FB_INTEGERSIZE*2
	
		case FB_TK_ULONGINT
			lexSkipToken( )
			dtype = FB_DATATYPE_ULONGINT
			lgt = FB_INTEGERSIZE*2
	
		case FB_TK_SINGLE
			lexSkipToken( )
			dtype = FB_DATATYPE_SINGLE
			lgt = 4
	
		case FB_TK_DOUBLE
			lexSkipToken( )
			dtype = FB_DATATYPE_DOUBLE
			lgt = 8
	
		case FB_TK_STRING
			lexSkipToken( )
	
			'' assume it's a var-len string, see below for fixed-len
			dtype = FB_DATATYPE_STRING
			lgt = FB_STRDESCLEN
	
		case FB_TK_ZSTRING
			lexSkipToken( )
	
			'' assume it's a pointer, see below for fixed-len
			dtype = FB_DATATYPE_CHAR
			lgt = 0
	
		case FB_TK_WSTRING
			lexSkipToken( )
	
	    	'' ditto
			dtype = FB_DATATYPE_WCHAR
	    	lgt = 0
	
		case FB_TK_FUNCTION, FB_TK_SUB
		    isfunction = (lexGetToken( ) = FB_TK_FUNCTION)
		    lexSkipToken( )
	
			dtype = FB_DATATYPE_POINTER + FB_DATATYPE_FUNCTION
			lgt = FB_POINTERSIZE
			ptrcnt = 1
	
			subtype = cSymbolTypeFuncPtr( isfunction )
			if( subtype = NULL ) then
				exit function
			end if
	
		case else
			dim as FBSYMCHAIN ptr chain_ = NULL
			dim as FBSYMBOL ptr base_parent = any
	        dim as integer id_options = FB_IDOPT_DEFAULT or FB_IDOPT_ALLOWSTRUCT
	  		dim as integer check_id = TRUE
	
	  		if( parser.stmt.with.sym <> NULL ) then
	  			if( lexGetToken( ) = CHAR_DOT ) then
	  				'' not a '..'?
	  				check_id = (lexGetLookAhead( 1, LEXCHECK_NOPERIOD ) = CHAR_DOT)
	  			end if
			end if
	        
	        if( check_id = TRUE ) then
				chain_ = cIdentifier( base_parent, id_options )
			end if
			
			if( chain_ = NULL ) then
				if( errGetLast( ) <> FB_ERRMSG_OK ) then
					exit function
				end if
	
			else
				do
					dim as FBSYMBOL ptr sym = chain_->sym
					do
						select case symbGetClass( sym )
						case FB_SYMBCLASS_STRUCT
							lexSkipToken( )
							dtype = FB_DATATYPE_STRUCT
							subtype = sym
							lgt = symbGetLen( sym )
							goto exit_search
	
		    			case FB_SYMBCLASS_ENUM
							lexSkipToken( )
							dtype = FB_DATATYPE_ENUM
							subtype = sym
							lgt = FB_INTEGERSIZE
							goto exit_search
	
						case FB_SYMBCLASS_TYPEDEF
							lexSkipToken( )
							dtype = symbGetType( sym )
							subtype = symbGetSubtype( sym )
							lgt = symbGetLen( sym )
							ptrcnt = symbGetPtrCnt( sym )
							goto exit_search
						end select
	
						sym = sym->hash.next
					loop while( sym <> NULL )
	
					chain_ = symbChainGetNext( chain_ )
				loop while( chain_ <> NULL )
	
exit_search:
			end if
		end select
	
		'' no type?
		if( dtype = INVALID ) then
			if( isunsigned ) then
				errReport( FB_ERRMSG_SYNTAXERROR )
			end if
	
			return FALSE
		end if
	
		'' unsigned?
		if( isunsigned ) then
			'' remap type, if valid
			select case as const dtype
			case FB_DATATYPE_BYTE
				dtype = FB_DATATYPE_UBYTE
	
			case FB_DATATYPE_SHORT
				dtype = FB_DATATYPE_USHORT
	
			case FB_DATATYPE_INTEGER
				dtype = FB_DATATYPE_UINT
	
			case FB_DATATYPE_LONG
				dtype = FB_DATATYPE_ULONG
	
			case FB_DATATYPE_LONGINT
				dtype = FB_DATATYPE_ULONGINT
	
			case else
				if( errReport( FB_ERRMSG_SYNTAXERROR, TRUE ) = FALSE ) then
					exit function
				end if
			end select
		end if
	end if

	'' fixed-len z|w|string? (must be handled here because the typedefs)
	if( lexGetToken( ) = CHAR_STAR ) then
		lexSkipToken( )

		'' expr
		if( cConstExprValue( lgt ) = FALSE ) then
			exit function
		end if

		select case as const dtype
		case FB_DATATYPE_STRING
			'' plus the null-term
			lgt += 1

			'' min 1 char (+ null-term)
			if( lgt <= 1 ) then
				if( errReport( FB_ERRMSG_SYNTAXERROR, TRUE ) = FALSE ) then
					exit function
				else
					'' error recovery: fake a len
					lgt = 2
				end if
			end if

			'' remap type
			dtype = FB_DATATYPE_FIXSTR

		case FB_DATATYPE_CHAR, FB_DATATYPE_WCHAR
			'' min 1 char
			if( lgt < 1 ) then
					if( errReport( FB_ERRMSG_SYNTAXERROR, TRUE ) = FALSE ) then
					exit function
				else
					'' error recovery: fake a len
					lgt = 1
				end if
			end if

			'' note: len of "wstring * expr" symbols will be actually
			''       the number of chars times sizeof(wstring), so
			''		 always use symbGetWstrLen( ) to retrieve the
			''       len in characters, not the bytes
			if( dtype = FB_DATATYPE_WCHAR ) then
				lgt *= symbGetDataSize( FB_DATATYPE_WCHAR )
			end if

		case else
			if( errReport( FB_ERRMSG_SYNTAXERROR, TRUE ) = FALSE ) then
				exit function
			end if

		end select

	else
		'' (PTR|POINTER)*
		do
			select case lexGetToken( )
			case FB_TK_PTR, FB_TK_POINTER
				lexSkipToken( )
				dtype += FB_DATATYPE_POINTER
				ptrcnt += 1
			case else
				exit do
			end select
		loop
	end if

	if( ptrcnt > 0 ) then
		lgt = FB_POINTERSIZE

	else
		'' can't have forward typedef's if they aren't pointers
		if( dtype = FB_DATATYPE_FWDREF ) then
			'' forward types are allowed in func prototypes with byref params
			if( (options and FB_SYMBTYPEOPT_ALLOWFORWARD) = 0 ) then
				if( errReport( FB_ERRMSG_INCOMPLETETYPE, TRUE ) = FALSE ) then
					exit function
				else
					'' error recovery: fake a type
					dtype = FB_DATATYPE_POINTER + FB_DATATYPE_VOID
					subtype = NULL
					ptrcnt = 1
				end if
			end if

		elseif( lgt <= 0 ) then
			select case dtype
			case FB_DATATYPE_CHAR, FB_DATATYPE_WCHAR
				'' LEN() and SIZEOF() allow Z|WSTRING to be used w/o PTR
				if( (options and FB_SYMBTYPEOPT_CHECKSTRPTR) <> 0 ) then
					if( errReport( FB_ERRMSG_EXPECTEDPOINTER ) = FALSE ) then
						exit function
					else
						'' error recovery: make pointer
						dtype += FB_DATATYPE_POINTER
						lgt = FB_POINTERSIZE
					end if

				else
					lgt = symbGetDataSize( dtype )
				end if
			end select
		end if
	end if

	function = TRUE

end function


