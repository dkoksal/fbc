'' intrinsic runtime lib memory functions (ALLOCATE, SWAP, ...)
''
'' chng: oct/2004 written [v1ctor]

#include once "fb.bi"
#include once "fbint.bi"
#include once "ast.bi"
#include once "rtl.bi"

	dim shared as FB_RTL_PROCDEF funcdata( 0 to ... ) = _
	{ _
		/' function fb_NullPtrChk _
			( _
				byval p as any ptr, _
				byval linenum as long, _
				byval fname as zstring ptr _
			) as any ptr '/ _
		( _
			@FB_RTL_NULLPTRCHK, NULL, _
	 		typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_FBCALL, _
	 		NULL, FB_RTL_OPT_NONE, _
			3, _
			{ _
				( typeAddrOf( FB_DATATYPE_VOID ),FB_PARAMMODE_BYVAL, FALSE ), _
				( FB_DATATYPE_LONG, FB_PARAMMODE_BYVAL, FALSE ), _
				( typeAddrOf( FB_DATATYPE_CHAR ),FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' function fb_MemCopy cdecl _
			( _
				byref dst as any, _
				byref src as any, _
				byval bytes as uinteger _
			) as any ptr '/ _
		( _
			@FB_RTL_MEMCOPY, @"memcpy", _
			typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_GCCBUILTIN, _
			3, _
			{ _
				( FB_DATATYPE_VOID,FB_PARAMMODE_BYREF, FALSE ), _
				( FB_DATATYPE_VOID,FB_PARAMMODE_BYREF, FALSE ), _
				( FB_DATATYPE_UINT, FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' sub fb_MemSwap( byref dst as any, byref src as any, byval bytes as integer ) '/ _
		( _
			@FB_RTL_MEMSWAP, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
	 		NULL, FB_RTL_OPT_NONE, _
			3, _
			{ _
				( FB_DATATYPE_VOID,FB_PARAMMODE_BYREF, FALSE ), _
				( FB_DATATYPE_VOID,FB_PARAMMODE_BYREF, FALSE ), _
				( FB_DATATYPE_INTEGER,FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' sub fb_MemCopyClear _
			( _
				byref dst as any, _
				byval dstlen as integer, _
				byref src as any, _
				byval srclen as integer _
			) '/ _
		( _
			@FB_RTL_MEMCOPYCLEAR, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
	 		NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( FB_DATATYPE_VOID,FB_PARAMMODE_BYREF, FALSE ), _
				( FB_DATATYPE_INTEGER,FB_PARAMMODE_BYVAL, FALSE ), _
				( FB_DATATYPE_VOID,FB_PARAMMODE_BYREF, FALSE ), _
				( FB_DATATYPE_INTEGER,FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' function fre( byval mode as long = 0 ) as uinteger '/ _
		( _
			@"fre", @"fb_GetMemAvail", _
			FB_DATATYPE_UINT, FB_FUNCMODE_FBCALL, _
	 		NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( FB_DATATYPE_LONG, FB_PARAMMODE_BYVAL, TRUE, 0 ) _
	 		} _
		), _
		/' function allocate cdecl( byval size as uinteger ) as any ptr '/ _
		( _
			@"allocate", @"malloc", _
			typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_NOQB, _
			1, _
			{ _
				( FB_DATATYPE_UINT,FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' function callocate cdecl( byval items as uinteger, byval size as uinteger = 1 ) as any ptr '/ _
		( _
			@"callocate", @"calloc", _
			typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_CDECL, _
 			NULL, FB_RTL_OPT_NOQB, _
			2, _
			{ _
				( FB_DATATYPE_UINT,FB_PARAMMODE_BYVAL, FALSE ), _
				( FB_DATATYPE_UINT,FB_PARAMMODE_BYVAL, TRUE, 1 ) _
	 		} _
		), _
		/' function reallocate cdecl( byval p as any ptr, byval size as uinteger ) as any ptr '/ _
		( _
			@"reallocate", @"realloc", _
			typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_CDECL, _
 			NULL, FB_RTL_OPT_NOQB, _
			2, _
			{ _
				( typeAddrOf( FB_DATATYPE_VOID ),FB_PARAMMODE_BYVAL, FALSE ), _
				( FB_DATATYPE_UINT,FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' sub deallocate cdecl( byval p as any ptr ) '/ _
		( _
			@"deallocate", @"free", _
			FB_DATATYPE_VOID, FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_NOQB, _
			1, _
			{ _
				( typeAddrOf( FB_DATATYPE_VOID ),FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' function clear cdecl _
			( _
				byref dst as any, _
				byval value as long = 0, _
				byval bytes as uinteger _
			) as any ptr '/ _
		( _
			@"clear", @"memset", _
			typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_GCCBUILTIN, _
			3, _
			{ _
				( FB_DATATYPE_VOID,FB_PARAMMODE_BYREF, FALSE ), _
				( FB_DATATYPE_LONG, FB_PARAMMODE_BYVAL, TRUE, 0 ), _
				( FB_DATATYPE_UINT, FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
	 	), _
		/' operator new cdecl( byval bytes as uinteger ) as any ptr '/ _
		( _
			cast( zstring ptr, AST_OP_NEW ), NULL, _
			typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_OVER or FB_RTL_OPT_OPERATOR, _
			1, _
			{ _
				( FB_DATATYPE_UINT, FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' operator new[] cdecl( byval bytes as uinteger ) as any ptr '/ _
		( _
			cast( zstring ptr, AST_OP_NEW_VEC ), NULL, _
			typeAddrOf( FB_DATATYPE_VOID ), FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_OVER or FB_RTL_OPT_OPERATOR, _
			1, _
			{ _
				( FB_DATATYPE_UINT, FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' operator delete cdecl( byval ptr as any ptr ) '/ _
		( _
			cast( zstring ptr, AST_OP_DEL ), NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_OVER or FB_RTL_OPT_OPERATOR, _
			1, _
			{ _
				( typeAddrOf( FB_DATATYPE_VOID ), FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
		/' operator delete[] cdecl( byval ptr as any ptr ) '/ _
		( _
			cast( zstring ptr, AST_OP_DEL_VEC ), NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_CDECL, _
	 		NULL, FB_RTL_OPT_OVER or FB_RTL_OPT_OPERATOR, _
			1, _
			{ _
				( typeAddrOf( FB_DATATYPE_VOID ), FB_PARAMMODE_BYVAL, FALSE ) _
	 		} _
		), _
	 	/' EOL '/ _
	 	( _
	 		NULL _
	 	) _
	 }

private sub hUpdateNewOpSizeParamType( byval op as AST_OP )
	dim as FBSYMBOL ptr sym = any
	sym = symbGetCompOpOvlHead( NULL, op )
	if( sym ) then
		sym = symbGetProcHeadParam( sym )
		if( sym ) then
			symbGetFullType( sym ) = iif( fbCpuTypeIs64bit( ), _
							env.target.size_t64, _
							env.target.size_t32 )
		end if
	end if
end sub

'':::::
sub rtlMemModInit( )

	rtlAddIntrinsicProcs( @funcdata(0) )

	'' remap the new/new[] size param, size_t can be unsigned (int | long),
	'' making the mangling incompatible..

	'' new
	hUpdateNewOpSizeParamType( AST_OP_NEW )

	'' new[]
	hUpdateNewOpSizeParamType( AST_OP_NEW_VEC )

end sub

'':::::
sub rtlMemModEnd( )

	'' procs will be deleted when symbEnd is called

end sub


'':::::
function rtlNullPtrCheck _
	( _
		byval p as ASTNODE ptr, _
		byval linenum as integer, _
		byval module as zstring ptr _
	) as ASTNODE ptr

    dim as ASTNODE ptr proc = any

   	function = NULL

   	proc = astNewCALL( PROCLOOKUP( NULLPTRCHK ) )

	'' ptr
	if( astNewARG( proc, _
				   astNewCONV( typeAddrOf( FB_DATATYPE_VOID ), NULL, p ), _
				   typeAddrOf( FB_DATATYPE_VOID ) ) = NULL ) then
		exit function
	end if

	'' linenum
	if( astNewARG( proc, astNewCONSTi( linenum ) ) = NULL ) then
		exit function
	end if

    '' module
	if( astNewARG( proc, astNewCONSTstr( module ) ) = NULL ) then
    	exit function
    end if

    function = proc

end function

'':::::
function rtlMemCopy _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr, _
		byval bytes as longint _
	) as ASTNODE ptr

    dim as ASTNODE ptr proc = any

	function = NULL

	''
    proc = astNewCALL( PROCLOOKUP( MEMCOPY ) )

    '' dst as any
    if( astNewARG( proc, dst ) = NULL ) then
    	exit function
    end if

    '' src as any
    if( astNewARG( proc, src ) = NULL ) then
    	exit function
    end if

	'' byval bytes as integer
	if( astNewARG( proc, astNewCONSTi( bytes ) ) = NULL ) then
		exit function
	end if

    ''
    function = proc

end function

'':::::
function rtlMemSwap _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr _
	) as integer

	function = FALSE

	dim as ASTNODE ptr proc = astNewCALL( PROCLOOKUP( MEMSWAP ) )

	'' always calc len before pushing the param
	dim as longint bytes = rtlCalcExprLen( dst )

	'' dst as any
	if( astNewARG( proc, dst ) = NULL ) then
		exit function
	end if

	'' src as any
	if( astNewARG( proc, src ) = NULL ) then
		exit function
	end if

	'' byval bytes as integer
	if( astNewARG( proc, astNewCONSTi( bytes ) ) = NULL ) then
		exit function
	end if

	astAdd( proc )

	function = TRUE
end function

'':::::
function rtlMemCopyClear _
	( _
		byval dstexpr as ASTNODE ptr, _
		byval dstlen as longint, _
		byval srcexpr as ASTNODE ptr, _
		byval srclen as longint _
	) as integer

    dim as ASTNODE ptr proc = any

	function = FALSE

	''
    proc = astNewCALL( PROCLOOKUP( MEMCOPYCLEAR ) )

    '' dst as any
    if( astNewARG( proc, dstexpr ) = NULL ) then
    	exit function
    end if

	'' byval dstlen as integer
	if( astNewARG( proc, astNewCONSTi( dstlen ) ) = NULL ) then
		exit function
	end if

    '' src as any
    if( astNewARG( proc, srcexpr ) = NULL ) then
    	exit function
    end if

	'' byval srclen as integer
	if( astNewARG( proc, astNewCONSTi( srclen ) ) = NULL ) then
		exit function
	end if

    ''
    astAdd( proc )

    function = TRUE

end function

function rtlMemNewOp _
	( _
		byval op as integer, _
		byval len_expr as ASTNODE ptr, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as FBSYMBOL ptr sym = any

	'' try to find an overloaded new()
	if( typeGet( dtype ) = FB_DATATYPE_STRUCT ) then
		assert( (astGetOpSelfVer( op ) = AST_OP_NEW_SELF) or (astGetOpSelfVer( op ) = AST_OP_NEW_VEC_SELF) )
		sym = symbGetCompOpOvlHead( subtype, astGetOpSelfVer( op ) )
		if( sym ) then
			if( symbCheckAccess( sym ) = FALSE ) then
				errReport( FB_ERRMSG_ILLEGALMEMBERACCESS )
			end if
		end if
	else
		sym = NULL
	end if

	'' if not defined, call the global one
	if( sym = NULL ) then
		assert( (op = AST_OP_NEW) or (op = AST_OP_NEW_VEC) )
		sym = symbGetCompOpOvlHead( NULL, op )
	end if

	proc = astNewCALL( sym )

	'' byval len as uinteger
	if( astNewARG( proc, len_expr ) = NULL ) then
		exit function
	end if

	function = proc
end function

function rtlMemDeleteOp _
	( _
		byval op as integer, _
		byval ptr_expr as ASTNODE ptr, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as FBSYMBOL ptr sym = any

	'' try to find an overloaded delete()
	if( typeGet( dtype ) = FB_DATATYPE_STRUCT ) then
		assert( (astGetOpSelfVer( op ) = AST_OP_DEL_SELF) or (astGetOpSelfVer( op ) = AST_OP_DEL_VEC_SELF) )
		sym = symbGetCompOpOvlHead( subtype, astGetOpSelfVer( op ) )
		if( sym ) then
			if( symbCheckAccess( sym ) = FALSE ) then
				errReport( FB_ERRMSG_ILLEGALMEMBERACCESS )
			end if
		end if
	else
		sym = NULL
	end if

	'' if not defined, call the global one
	if( sym = NULL ) then
		assert( (op = AST_OP_DEL) or (op = AST_OP_DEL_VEC) )
		sym = symbGetCompOpOvlHead( NULL, op )
	end if

	proc = astNewCALL( sym )

	'' byval ptr as any ptr
	if( astNewARG( proc, ptr_expr ) = NULL ) then
		exit function
	end if

	function = proc
end function
