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

'' AST misc helpers/builders
''
'' chng: sep/2006 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\ir.bi"
#include once "inc\ast.bi"
#include once "inc\lex.bi"
#include once "inc\rtl.bi"

''
'' vars
''

'':::::
function astBuildVarAssign _
	( _
		byval lhs as FBSYMBOL ptr, _
		byval rhs as integer _
	) as ASTNODE ptr

	function = astNewASSIGN( astNewVAR( lhs, _
            							0, _
            							symbGetType( lhs ), _
            							symbGetSubtype( lhs ) ), _
            				 astNewCONSTi( rhs, _
            				 			   FB_DATATYPE_INTEGER ) )

end function

'':::::
function astBuildVarAssign _
	( _
		byval lhs as FBSYMBOL ptr, _
		byval rhs as ASTNODE ptr _
	) as ASTNODE ptr

	function = astNewASSIGN( astNewVAR( lhs, _
            							0, _
            							symbGetType( lhs ), _
            							symbGetSubtype( lhs ) ), _
            				 rhs )

end function

'':::::
function astBuildVarInc _
	( _
		byval lhs as FBSYMBOL ptr, _
		byval rhs as integer _
	) as ASTNODE ptr

	dim as AST_OPOPT options = any
	dim as AST_OP op = any

	options = AST_OPOPT_DEFAULT
	if( typeIsPOINTER( symbGetType( lhs ) ) ) then
		options or= AST_OPOPT_LPTRARITH
	end if

	if( rhs > 0 ) then
		op = AST_OP_ADD_SELF
	else
		op = AST_OP_SUB_SELF
		rhs = -rhs
	end if

	function = astNewSelfBOP( op, _
						   	  astNewVAR( lhs, _
						   	  			 0, _
						   	  			 symbGetType( lhs ), _
						   	  			 symbGetSubtype( lhs ) ), _
            			   	  astNewCONSTi( rhs, _
            			   	  				FB_DATATYPE_INTEGER ), _
            			   	  NULL, _
            			   	  options )

end function

'':::::
function astBuildVarDeref _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

	function = astNewDEREF( astNewVAR( sym, _
            						   0, _
            						   symbGetType( sym ), _
            						   symbGetSubtype( sym ) ), _
            			  	symbGetType( sym ) - FB_DATATYPE_POINTER, _
            			  	symbGetSubtype( sym ) )

end function

'':::::
function astBuildVarDeref _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	function = astNewDEREF( expr )

end function

'':::::
function astBuildVarAddrof _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

	function = astNewADDROF( astNewVAR( sym, _
            						  	0, _
            						  	symbGetType( sym ), _
            						  	symbGetSubtype( sym ) ) )

end function

'':::::
function astBuildVarDtorCall _
	( _
		byval s as FBSYMBOL ptr, _
		byval check_access as integer _
	) as ASTNODE ptr

	dim as integer do_free = any
	dim as ASTNODE ptr expr = any

	'' assuming conditions were checked already
	function = NULL

	'' array? dims can be -1 with "DIM foo()" arrays..
	if( symbGetArrayDimensions( s ) <> 0 ) then
		do_free = FALSE

		'' dynamic?
		if( symbIsDynamic( s ) ) then
			do_free = TRUE

		else
		     '' has dtor?
		     select case symbGetType( s )
		     case FB_DATATYPE_STRUCT ', FB_DATATYPE_CLASS
			 	do_free = symbGetHasDtor( symbGetSubtype( s ) )
			 end select
		end if

		if( do_free ) then
			expr = astNewVAR( s, 0, symbGetType( s ), symbGetSubtype( s ) )

			if( symbIsDynamic( s ) ) then
				function = rtlArrayErase( expr, check_access )
			else
				function = rtlArrayClear( expr, FALSE, check_access )
			end if

		'' array of dyn strings?
		elseif( symbGetType( s ) = FB_DATATYPE_STRING ) then
			function = rtlArrayStrErase( astNewVAR( s, 0, FB_DATATYPE_STRING ) )
		end if

	else
		select case symbGetType( s )
		'' dyn string?
		case FB_DATATYPE_STRING
			function = rtlStrDelete( astNewVAR( s, 0, FB_DATATYPE_STRING ) )

		'' struct or class?
		case FB_DATATYPE_STRUCT ', FB_DATATYPE_CLASS
			'' has dtor?
			if( symbGetHasDtor( symbGetSubtype( s ) ) ) then
                dim as FBSYMBOL ptr subtype = symbGetSubtype( s )

                if( check_access ) then
					if( symbCheckAccess( subtype, _
										 symbGetCompDtor( subtype ) ) = FALSE ) then
						errReport( FB_ERRMSG_NOACCESSTODTOR )
                	end if
                end if

                function = astBuildDtorCall( subtype, _
                							 astNewVAR( s, _
                							 			0, _
                							 			symbGetType( s ), _
                							 			subtype ) )

			end if

		end select
	end if

end function

'':::::
function astBuildVarField _
	( _
		byval sym as FBSYMBOL ptr, _
		byval fld as FBSYMBOL ptr, _
		byval ofs as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr expr = any

	if( fld <> NULL ) then
		ofs += symbGetOfs( fld )
	end if

	'' byref or import?
	if( symbIsParamByRef( sym ) or symbIsImport( sym ) ) then
		expr = astNewDEREF( astNewVAR( sym, _
						    		   0, _
						    		   FB_DATATYPE_POINTER + symbGetType( sym ), _
						    		   symbGetSubtype( sym ) ), _
						    symbGetType( sym ), _
						    symbGetSubtype( sym ), _
						    ofs )
	else
		expr = astNewVAR( sym, _
						  ofs, _
						  symbGetType( sym ), _
						  symbGetSubtype( sym ) )
	end if

	if( fld <> NULL ) then
		expr = astNewFIELD( expr, fld, symbGetType( fld ), symbGetSubtype( fld ) )
	end if

	function = expr

end function

''
'' loops
''

'':::::
function astBuildForBeginEx _
	( _
		byval tree as ASTNODE ptr, _
		byval cnt as FBSYMBOL ptr, _
		byval label as FBSYMBOL ptr, _
		byval inivalue as integer _
	) as ASTNODE ptr

	'' cnt = 0
    tree = astNewLINK( tree, astBuildVarAssign( cnt, inivalue ) )

    '' do
    tree = astNewLINK( tree, astNewLABEL( label ) )

    function = tree

end function

'':::::
sub astBuildForBegin _
	( _
		byval cnt as FBSYMBOL ptr, _
		byval label as FBSYMBOL ptr, _
		byval inivalue as integer _
	)

    astAdd( astBuildForBeginEx( NULL, cnt, label, inivalue ) )

end sub

'':::::
function astBuildForEndEx _
	( _
		byval tree as ASTNODE ptr, _
		byval cnt as FBSYMBOL ptr, _
		byval label as FBSYMBOL ptr, _
		byval stepvalue as integer, _
		byval endvalue as ASTNODE ptr _
	) as ASTNODE ptr

	'' next
    tree = astNewLINK( tree, astBuildVarInc( cnt, stepvalue ) )

    '' next
    tree = astNewLINK( tree, astUpdComp2Branch( astNewBOP( AST_OP_EQ, _
    									  				   astNewVAR( cnt, _
            										 	   			  0, _
            										 	   			  FB_DATATYPE_INTEGER ), _
            							  				   endvalue ), _
            				   					label, _
            				   					FALSE ) )

	function = tree

end function

'':::::
function astBuildForEndEx _
	( _
		byval tree as ASTNODE ptr, _
		byval cnt as FBSYMBOL ptr, _
		byval label as FBSYMBOL ptr, _
		byval stepvalue as integer, _
		byval endvalue as integer _
	) as ASTNODE ptr

	function = astBuildForEndEx( tree, _
								 cnt, _
								 label, _
								 stepvalue, _
								 astNewCONSTi( endvalue, FB_DATATYPE_INTEGER ) )

end function

'':::::
sub astBuildForEnd _
	( _
		byval cnt as FBSYMBOL ptr, _
		byval label as FBSYMBOL ptr, _
		byval stepvalue as integer, _
		byval endvalue as ASTNODE ptr _
	)

    astAdd( astBuildForEndEx( NULL, cnt, label, stepvalue, endvalue ) )

end sub

'':::::
sub astBuildForEnd _
	( _
		byval cnt as FBSYMBOL ptr, _
		byval label as FBSYMBOL ptr, _
		byval stepvalue as integer, _
		byval endvalue as integer _
	)

    astBuildForEnd( cnt, _
    				label, _
    				stepvalue, _
    				astNewCONSTi( endvalue, FB_DATATYPE_INTEGER ) )

end sub

''
'' calls
''

'':::::
function astBuildCall cdecl _
	( _
		byval proc as FBSYMBOL ptr, _
		byval args as integer, _
		... _
	) as ASTNODE ptr

    dim as ASTNODE ptr p = any
    dim as any ptr arg  = any
    dim as integer i  = any

    p = astNewCALL( proc )

    arg = va_first( )
    for i = 0 to args-1
    	if( astNewARG( p, va_arg( arg, ASTNODE ptr ) ) = NULL ) then
    		return NULL
    	end if

    	arg = va_next( arg, ASTNODE ptr )
    next

    function = p

end function

'':::::
function astBuildCtorCall _
	( _
		byval sym as FBSYMBOL ptr, _
		byval thisexpr as ASTNODE ptr _
	) as ASTNODE ptr

    dim as FBSYMBOL ptr ctor = any
    dim as ASTNODE ptr proc = any
    dim as integer params = any

    ctor = symbGetCompDefCtor( sym )
    if( ctor = NULL ) then
    	return NULL
    end if

    proc = astNewCALL( ctor )

    astNewARG( proc, thisexpr )

    '' add the optional params, if any
    params = symbGetProcParams( ctor ) - 1
    do while( params > 0 )
    	astNewARG( proc, NULL )
    	params -= 1
    loop

    function = proc

end function

'':::::
function astBuildDtorCall _
	( _
		byval sym as FBSYMBOL ptr, _
		byval thisexpr as ASTNODE ptr _
	) as ASTNODE ptr

    dim as ASTNODE ptr proc = any

    proc = astNewCALL( symbGetCompDtor( sym ) )

    astNewARG( proc, thisexpr )

    function = proc

end function

'':::::
function astBuildCopyCtorCall _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr _
	) as ASTNODE ptr

    dim as ASTNODE ptr proc = any
    dim as FBSYMBOL ptr copyctor = any

	copyctor = symbGetCompCopyCtor( astGetSubtype( dst ) )

	'' no copy ctor? do a shallow copy..
	if( copyctor = NULL ) then
    	return astNewASSIGN( dst, src, AST_OPOPT_DONTCHKPTR )
    end if

    '' call the copy ctor
    proc = astNewCALL( copyctor )

    astNewARG( proc, dst )
    astNewARG( proc, src )

    function = proc

end function

'':::::
function astPatchCtorCall _
	( _
		byval procexpr as ASTNODE ptr, _
		byval thisexpr as ASTNODE ptr _
	) as ASTNODE ptr

	if( procexpr <> NULL ) then
		'' replace the instance pointer
		astReplaceARG( procexpr, 0, thisexpr )
	end if

	function = procexpr

end function

'':::::
function astCALLCTORToCALL _
	( _
		byval n as ASTNODE ptr _
	) as ASTNODE ptr

	dim as FBSYMBOL ptr sym = any
	dim as ASTNODE ptr procexpr = any

	sym = astGetSymbol( n->r )

	'' the function call is in the left leaf
	procexpr = n->l

	'' remove right leaf
	astDelTree( n->r )

	'' remove anon symbol
	if( symbGetHasDtor( symbGetSubtype( sym ) ) ) then
		'' if the temp has a dtor it was added to the dtor list,
		'' remove it too
		astDtorListDel( sym )
	end if

	symbDelSymbol( sym )

	'' remove the node
	astDelNode( n )

	function = procexpr

end function

''::::
function astBuildImplicitCtorCall _
	( _
		byval subtype as FBSYMBOL ptr, _
		byval expr as ASTNODE ptr, _
		byval arg_mode as FB_PARAMMODE, _
		byref is_ctorcall as integer _
	) as ASTNODE ptr

 	dim as integer err_num = any
    dim as FBSYMBOL ptr proc = any

	proc = symbFindCtorOvlProc( subtype, expr, arg_mode, @err_num )
	if( proc = NULL ) then
		is_ctorcall = FALSE

		if( err_num <> FB_ERRMSG_OK ) then
			errReportParam( symbGetCompCtorHead( subtype ), 0, NULL, err_num )
			return NULL
		end if

		'' could be a shallow copy..
        return expr
	end if

    '' check visibility
	if( symbCheckAccess( subtype, proc ) = FALSE ) then
		errReport( FB_ERRMSG_NOACCESSTOCTOR )
	end if

    '' build a ctor call
    dim as ASTNODE ptr procexpr = astNewCALL( proc )

    '' push the mock instance ptr
    astNewARG( procexpr, astBuildMockInstPtr( subtype ), INVALID, FB_PARAMMODE_BYVAL )

    astNewARG( procexpr, expr, INVALID, arg_mode )

    '' add the optional params, if any
    dim as integer params = symbGetProcParams( proc ) - 2
    do while( params > 0 )
    	astNewARG( procexpr, NULL )
    	params -= 1
    loop

    is_ctorcall = TRUE
    function = procexpr

end function

'':::::
function astBuildImplicitCtorCallEx _
	( _
		byval sym as FBSYMBOL ptr, _
		byval expr as ASTNODE ptr, _
		byval arg_mode as FB_PARAMMODE, _
		byref is_ctorcall as integer _
	) as ASTNODE ptr

    dim as FBSYMBOL ptr subtype = any

	subtype = symbGetSubType( sym )

    '' check ctor call
    if( astIsCALLCTOR( expr ) ) then
    	if( symbGetSubtype( expr ) = subtype ) then
    		is_ctorcall = TRUE
    		'' remove the the anon/temp instance
    		return astCALLCTORToCALL( expr )
    	end if
    end if

    '' try calling any ctor with the expression
    function = astBuildImplicitCtorCall( subtype, expr, arg_mode, is_ctorcall )

end function

''
'' procs
''

'':::::
function astBuildProcAddrof _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

	function = astNewADDROF( astNewVAR( sym, _
						   			  	0, _
						   			  	FB_DATATYPE_FUNCTION, _
						   			  	sym ) )

end function

'':::::
function astBuildProcBegin _
	( _
		byval proc as FBSYMBOL ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr n = any

	n = astProcBegin( proc, FALSE )

    symbSetProcIncFile( proc, env.inf.incfile )

   	astAdd( astNewLABEL( astGetProcInitlabel( n ) ) )

   	function = n

end function

'':::::
sub astBuildProcEnd _
	( _
		byval n as ASTNODE ptr _
	)

	astProcEnd( n, FALSE )

end sub

'':::::
function astBuildProcResultVar _
	( _
		byval proc as FBSYMBOL ptr, _
		byval res as FBSYMBOL ptr _
	) as ASTNODE ptr

    dim as ASTNODE PTR lhs = any

    lhs = astNewVAR( res, 0, symbGetType( res ), symbGetSubtype( res ) )

	'' proc returns an UDT?
    select case symbGetType( proc )
    case FB_DATATYPE_STRUCT
		'' pointer? deref
		if( symbGetProcRealType( proc ) = FB_DATATYPE_POINTER + FB_DATATYPE_STRUCT ) then
			lhs = astNewDEREF( lhs, FB_DATATYPE_STRUCT, symbGetSubtype( res ) )
		end if
	'case FB_DATATYPE_CLASS
		' ...
	end select

	function = lhs

end function

'':::::
function astBuildCallHiddenResVar _
	( _
		byval callexpr as ASTNODE ptr _
	) as ASTNODE ptr

    function = astNewLINK( callexpr, _
						   astNewVAR( callexpr->call.tmpres, _
        							  0, _
        							  astGetDataType( callexpr ), _
        							  astGetSubtype( callexpr ) ), _
        				   FALSE )

end function

''
'' instance ptr
''

'':::::
function astBuildInstPtr _
	( _
		byval sym as FBSYMBOL ptr, _
		byval fld as FBSYMBOL ptr, _
		byval idxexpr as ASTNODE ptr, _
		byval ofs as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr expr = any
	dim as integer dtype = any
	dim as FBSYMBOL ptr subtype = any

	dtype = symbGetType( sym )
	subtype = symbGetSubtype( sym )

	'' it's always an param
	expr = astNewVAR( sym, 0, FB_DATATYPE_POINTER + dtype, subtype )

	if( fld <> NULL ) then
		dtype = symbGetType( fld )
		subtype = symbGetSubtype( fld )

		'' build sym.field( index )

		ofs += symbGetOfs( fld )
		if( ofs <> 0 ) then
			expr = astNewBOP( AST_OP_ADD, _
						  	  expr, _
						  	  astNewCONSTi( ofs, FB_DATATYPE_INTEGER ) )
		end if

		'' array access?
	   	if( idxexpr <> NULL ) then
			'' times length
			expr = astNewBOP( AST_OP_ADD, _
						  	  expr, _
						  	  astNewBOP( AST_OP_MUL, _
						     		 	 idxexpr, _
						  	 		 	 astNewCONSTi( symbGetLen( fld ), _
						  	 		 	 			   FB_DATATYPE_INTEGER ) ) )
		end if

    else
		if( ofs <> 0 ) then
			expr = astNewBOP( AST_OP_ADD, _
						  	  expr, _
						  	  astNewCONSTi( ofs, FB_DATATYPE_INTEGER ) )
		end if
	end if

	expr = astNewDEREF( expr, dtype, subtype )

	if( fld <> NULL ) then
	    expr = astNewFIELD( expr, fld, dtype, subtype )
	end if

	function = expr

end function

'':::::
function astBuildMockInstPtr _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

	function = astNewCONSTi( 0, _
							 FB_DATATYPE_POINTER + symbGetType( sym ), _
							 sym )

end function

''
'' misc
''

'':::::
function astBuildTypeIniCtorList _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr tree

	tree = astTypeIniBegin( symbGetType( sym ), symbGetSubtype( sym ), TRUE )

	astTypeIniAddCtorList( tree, sym, symbGetArrayElements( sym ) )

	astTypeIniEnd( tree, TRUE )

	function = tree

end function

'':::::
function astBuildMultiDeref _
	( _
		byval cnt as integer, _
		byval expr as ASTNODE ptr, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr _
	) as ASTNODE ptr

	do while( cnt > 0 )
		if( dtype < FB_DATATYPE_POINTER ) then
			if( symb.globOpOvlTb(AST_OP_DEREF).head = NULL ) then
				if( errReport( FB_ERRMSG_EXPECTEDPOINTER, TRUE ) = FALSE ) then
					return NULL
				else
					exit do
				end if
			end if

			'' check op overloading
    		dim as FBSYMBOL ptr proc = any
    		dim as FB_ERRMSG err_num = any

			proc = symbFindUopOvlProc( AST_OP_DEREF, expr, @err_num )
			if( proc <> NULL ) then
    			'' build a proc call
				expr = astBuildCall( proc, 1, expr )
				if( expr = NULL ) then
					return NULL
				end if

				dtype = astGetDataType( expr )
				subtype = astGetSubType( expr )

			else
				if( errReport( FB_ERRMSG_EXPECTEDPOINTER, TRUE ) = FALSE ) then
					return NULL
				else
					exit do
				end if
			end if


		else
			typeStripPOINTER( dtype, subtype )

			'' incomplete type?
			select case dtype
			case FB_DATATYPE_VOID, FB_DATATYPE_FWDREF
				if( errReport( FB_ERRMSG_INCOMPLETETYPE, TRUE ) = FALSE ) then
					return NULL
				else
					'' error recovery: fake a type
					dtype = FB_DATATYPE_BYTE
				end if
			end select

			'' null pointer checking
			if( env.clopt.extraerrchk ) then
				expr = astNewPTRCHK( expr, lexLineNum( ) )
			end if

			expr = astNewDEREF( expr, dtype, subtype )
		end if

		cnt -= 1
	loop

	function = expr

end function

''
'' arrays
''

'':::::
function astBuildArrayDescIniTree _
	( _
		byval desc as FBSYMBOL ptr, _
		byval array as FBSYMBOL ptr, _
		byval array_expr as ASTNODE ptr _
	) as ASTNODE ptr

    dim as ASTNODE ptr tree = any
    dim as integer dtype = any, dims = any
    dim as FBSYMBOL ptr elm = any, dimtb = any, subtype = any

    '' COMMON?
    if( symbIsCommon( array ) ) then
    	return NULL
    end if

    ''
    tree = astTypeIniBegin( symbGetType( desc ), symbGetSubtype( desc ), TRUE )

    dtype = symbGetType( array )
    subtype = symbGetSubType( array )
    dims = symbGetArrayDimensions( array )

	'' unknown dimensions? use max..
	if( dims = -1 ) then
		dims = FB_MAXARRAYDIMS
	end if

	'' note: assuming the arrays descriptors won't be objects with methods
	elm = symbGetUDTSymbTbHead( symbGetSubtype( desc ) )

    if( array_expr = NULL ) then
    	if( symbGetIsDynamic( array ) ) then
    		array_expr = astNewCONSTi( 0, FB_DATATYPE_POINTER + dtype, subtype )
    	else
    		array_expr = astNewADDROF( astNewVAR( array, 0, dtype, subtype ) )
    	end if

    else
    	array_expr = astNewADDROF( array_expr )
    end if

    '' .data = @array(0) + diff
	astTypeIniAddAssign( tree, _
					   	 astNewBOP( AST_OP_ADD, _
								  	astCloneTree( array_expr ), _
					   			  	astNewCONSTi( symbGetArrayOffset( array ), _
					   			  				  FB_DATATYPE_INTEGER ) ), _
					   	 elm )

	elm = symbGetNext( elm )

	'' .ptr	= @array(0)
	astTypeIniAddAssign( tree, array_expr, elm )

    elm = symbGetNext( elm )

    '' .size = len( array ) * elements( array )
    astTypeIniAddAssign( tree, _
    				   	 astNewCONSTi( symbGetLen( array ) * symbGetArrayElements( array ), _
    				   				   FB_DATATYPE_INTEGER ), _
    				   	 elm )

    elm = symbGetNext( elm )

    '' .element_len	= len( array )
    astTypeIniAddAssign( tree, _
    				   	 astNewCONSTi( symbGetLen( array ), _
    				   				   FB_DATATYPE_INTEGER ), _
    				   	 elm )

    elm = symbGetNext( elm )

    '' .dimensions = dims( array )
    astTypeIniAddAssign( tree, _
    				   	 astNewCONSTi( dims, _
    				   				   FB_DATATYPE_INTEGER ), _
    				   	 elm )

    elm = symbGetNext( elm )

    '' setup dimTB
    dimtb = symbGetUDTSymbTbHead( symbGetSubtype( elm ) )

    '' static array?
    if( symbGetIsDynamic( array ) = FALSE ) then
    	dim as FBVARDIM ptr d

    	d = symbGetArrayFirstDim( array )
    	do while( d <> NULL )
			elm = dimtb

			'' .elements = (ubound( array, d ) - lbound( array, d )) + 1
    		astTypeIniAddAssign( tree, _
    				   		     astNewCONSTi( d->upper - d->lower + 1, _
    				   				 		   FB_DATATYPE_INTEGER ), _
    				   		     elm )

			elm = symbGetNext( elm )

			'' .lbound = lbound( array, d )
    		astTypeIniAddAssign( tree, _
    				   		     astNewCONSTi( d->lower, _
    				   				 		   FB_DATATYPE_INTEGER ), _
    				   		     elm )

			elm = symbGetNext( elm )

			'' .ubound = ubound( array, d )
    		astTypeIniAddAssign( tree, _
    				   		     astNewCONSTi( d->upper, _
    				   				 		   FB_DATATYPE_INTEGER ), _
    				   		     elm )

			d = d->next
    	loop

    '' dynamic..
    else
        '' just fill with 0's
        astTypeIniAddPad( tree, dims * len( FB_ARRAYDESCDIM ) )
    end if

    ''
    astTypeIniEnd( tree, TRUE )

    ''
    symbSetIsInitialized( desc )

    function = tree

end function

''
'' strings
''

'':::::
function astBuildStrPtr _
	( _
		byval lhs as ASTNODE ptr _
	) as ASTNODE ptr

	'' note: only var-len strings expressions should be passed

	'' *cast( zstring ptr ptr, @lhs )
	function = astNewDEREF( astNewCONV( FB_DATATYPE_POINTER*2 + FB_DATATYPE_CHAR, _
								 	    NULL, _
								 	  	astNewADDROF( lhs ) ), _
						  	FB_DATATYPE_POINTER + FB_DATATYPE_CHAR, _
						  	NULL )

end function


