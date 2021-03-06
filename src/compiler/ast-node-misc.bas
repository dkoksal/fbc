'' AST misc nodes
''
'' chng: sep/2004 written [v1ctor]


#include once "fb.bi"
#include once "fbint.bi"
#include once "lex.bi"
#include once "parser.bi"
#include once "ir.bi"
#include once "ast.bi"
#include once "emit.bi"

'' Labels (l = NULL; r = NULL)
function astNewLABEL _
	( _
		byval sym as FBSYMBOL ptr, _
		byval doflush as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr n = any

	n = astNewNode( AST_NODECLASS_LABEL, FB_DATATYPE_INVALID )

	n->sym = sym
	n->lbl.flush = doflush

	if( symbIsLabel( sym ) ) then
		if( symbGetLabelIsDeclared( sym ) = FALSE ) then
			symbSetLabelIsDeclared( sym )
			symbGetLabelStmt( sym ) = parser.stmt.cnt
			symbGetLabelParent( sym ) = parser.currblock
		end if
	end if

	function = n
end function

function astLoadLABEL( byval n as ASTNODE ptr ) as IRVREG ptr
	if( ast.doemit ) then
		if( n->lbl.flush ) then
			irEmitLABEL( n->sym )
		else
			irEmitLABELNF( n->sym )
		end if
	end if

	function = NULL
end function

'' Literals (l = NULL; r = NULL)
function astNewLIT( byval text as zstring ptr ) as ASTNODE ptr
	dim as ASTNODE ptr n = any

	n = astNewNode( AST_NODECLASS_LIT, FB_DATATYPE_INVALID )

	n->lit.text = ZstrAllocate( len( *text ) )
	*n->lit.text = *text

	function = n
end function

function astLoadLIT( byval n as ASTNODE ptr ) as IRVREG ptr
	if( ast.doemit ) then
		irEmitCOMMENT( n->lit.text )
	end if

	ZstrFree( n->lit.text )

	function = NULL
end function

private function astAsmAppend _
	( _
		byval tail as ASTASMTOK ptr, _
		byval typ as integer _
	) as ASTASMTOK ptr

	dim as ASTASMTOK ptr asmtok = any

	asmtok = listNewNode( @ast.asmtoklist )

	if( tail ) then
		tail->next = asmtok
	end if
	asmtok->type = typ
	asmtok->next = NULL

	function = asmtok
end function

function astAsmAppendText _
	( _
		byval tail as ASTASMTOK ptr, _
		byval text as zstring ptr _
	) as ASTASMTOK ptr

	tail = astAsmAppend( tail, AST_ASMTOK_TEXT )

	tail->text = ZstrAllocate( len( *text ) )
	*tail->text = *text

	function = tail
end function

function astAsmAppendSymb _
	( _
		byval tail as ASTASMTOK ptr, _
		byval sym as FBSYMBOL ptr _
	) as ASTASMTOK ptr

	tail = astAsmAppend( tail, AST_ASMTOK_SYMB )

	tail->sym = sym

	function = tail
end function

'' ASM (l = NULL; r = NULL)
function astNewASM( byval asmtokhead as ASTASMTOK ptr ) as ASTNODE ptr
	dim as ASTNODE ptr n = any

	n = astNewNode( AST_NODECLASS_ASM, FB_DATATYPE_INVALID )

	n->asm.tokhead = asmtokhead

	function = n
end function

function astLoadASM( byval n as ASTNODE ptr ) as IRVREG ptr
	dim as ASTASMTOK ptr node = any, nxt = any

	if( ast.doemit ) then
		irEmitAsmBegin( )
	end if

	node = n->asm.tokhead
	while( node )
		nxt = node->next

		select case( node->type )
		case AST_ASMTOK_TEXT
			if( ast.doemit ) then
				irEmitAsmText( node->text )
			end if
			ZstrFree( node->text )
		case AST_ASMTOK_SYMB
			if( ast.doemit ) then
				irEmitAsmSymb( node->sym )
			end if
		end select

		listDelNode( @ast.asmtoklist, node )
		node = nxt
	wend

	if( ast.doemit ) then
		irEmitAsmEnd( )
	end if

	function = NULL
end function

'' Debug (l = NULL; r = NULL)
function astNewDBG _
	( _
		byval op as integer, _
		byval ex as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr n = any

	if( env.clopt.debug = FALSE ) then
		return NULL
	end if

	n = astNewNode( AST_NODECLASS_DBG, FB_DATATYPE_INVALID )

	n->dbg.op = op
	n->dbg.ex = ex

	function = n
end function

function astLoadDBG( byval n as ASTNODE ptr ) as IRVREG ptr
	if( ast.doemit ) then
		irEmitDBG( n->dbg.op, astGetProc( )->sym, n->dbg.ex )
	end if

	function = NULL
end function

'' No Operation (l = NULL; r = NULL)
function astNewNOP( ) as ASTNODE ptr
	dim as ASTNODE ptr n = any

	n = astNewNode( AST_NODECLASS_NOP, FB_DATATYPE_INVALID )

	function = n
end function

function astLoadNOP( byval n as ASTNODE ptr ) as IRVREG ptr
	'' do nothing
	function = NULL
end function

'' Non-Indexed Array (l = expr; r = NULL)
function astNewNIDXARRAY( byval expr as ASTNODE ptr ) as ASTNODE ptr
	dim as ASTNODE ptr n = any

	n = astNewNode( AST_NODECLASS_NIDXARRAY, FB_DATATYPE_INVALID )

	n->l = expr

	function = n
end function

function astLoadNIDXARRAY( byval n as ASTNODE ptr ) as IRVREG ptr
	astDelTree( n->l )
	function = NULL
end function

'' Links (l = statement 1; r = statement 2)
function astNewLINK _
	( _
		byval l as ASTNODE ptr, _
		byval r as ASTNODE ptr, _
		byval ret_left as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr n = any

	if( l = NULL ) then
		return r
	end if

	if( r = NULL ) then
		return l
	end if

	if( ret_left ) then
		n = astNewNode( AST_NODECLASS_LINK, astGetFullType( l ), l->subtype )
	else
		n = astNewNode( AST_NODECLASS_LINK, astGetFullType( r ), r->subtype )
	end if

	n->link.ret_left = ret_left
	n->l = l
	n->r = r

	function = n
end function

function astLoadLINK( byval n as ASTNODE ptr ) as IRVREG ptr
	dim as IRVREG ptr vrl = any, vrr = any

	vrl = astLoad( n->l )
	astDelNode( n->l )

	vrr = astLoad( n->r )
	astDelNode( n->r )

	if( n->link.ret_left ) then
		function = vrl
	else
		function = vrr
	end if
end function

'' Explicit loads (l = expression to load to a register; r = NULL)
function astNewLOAD _
	( _
		byval l as ASTNODE ptr, _
		byval dtype as integer, _
		byval isresult as integer _
	) as ASTNODE ptr

	'' alloc new node
	dim as ASTNODE ptr n = astNewNode( AST_NODECLASS_LOAD, dtype )

	n->l  = l
	n->lod.isres = isresult

	function = n
end function

function astLoadLOAD( byval n as ASTNODE ptr ) as IRVREG ptr
	dim as ASTNODE ptr l = any
	dim as IRVREG ptr v1 = any, vr = any

	l = n->l
	if( l = NULL ) then
		return NULL
	end if

	v1 = astLoad( l )

	if( ast.doemit ) then
		if( n->lod.isres ) then
			vr = irAllocVREG( irGetVRDataType( v1 ), irGetVRSubType( v1 ) )
			irEmitLOADRES( v1, vr )
		else
			irEmitLOAD( v1 )
		end if
	end if

	astDelNode( l )

	function = v1
end function

'' Field accesses - used in expression trees to be able to identify bitfield
'' assignments/accesses, and also by astOptimizeTree() to optimize nested field
'' accesses.
'' l = field access; r = NULL
function astNewFIELD _
	( _
		byval l as ASTNODE ptr, _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr n = any
	dim as integer dtype = any
	dim as FBSYMBOL ptr subtype = any

	dtype = l->dtype
	subtype = l->subtype

	if( typeGetDtAndPtrOnly( dtype ) = FB_DATATYPE_BITFIELD ) then
		'' final type is always an unsigned int
		dtype = typeJoin( dtype, FB_DATATYPE_UINT )
		subtype = NULL

		ast.bitfieldcount += 1

		'' Note: We can't generate bitfield access code here yet,
		'' because we don't know whether this will be a load from or
		'' store to a bitfield.
	end if

	n = astNewNode( AST_NODECLASS_FIELD, dtype, subtype )
	n->sym = sym
	n->l = l

	function = n
end function

'' Decrease bitfield counter for the bitfield FIELD nodes in this tree,
'' to be used on field/parameter initializers that are never astAdd()ed,
'' but only ever cloned.
sub astForgetBitfields( byval n as ASTNODE ptr )
	if( (n = NULL) or (ast.bitfieldcount <= 0) ) then
		exit sub
	end if

	if( astIsBITFIELD( n ) ) then
		ast.bitfieldcount -= 1
	end if

	astForgetBitfields( n->l )
	astForgetBitfields( n->r )
end sub

private function astSetBitfield _
	( _
		byval l as ASTNODE ptr, _
		byval r as ASTNODE ptr _
	) as ASTNODE ptr

	dim as FBSYMBOL ptr s = any

	''
	''    l<bitfield> = r
	'' becomes:
	''    l<int> = (l<int> and mask) or ((r and bits) shl bitpos)
	''

	s = l->subtype
	assert( symbIsBitfield( s ) )

	'' Remap type from bitfield to short/integer/etc., whichever was given
	'' on the bitfield, to do a "full" field access.
	astGetFullType( l ) = symbGetFullType( s )
	l->subtype = s->subtype

	'' l is reused on the rhs and thus must be duplicated
	l = astCloneTree( l )

	'' Apply a mask to retrieve all bits but the bitfield's ones
	l = astNewBOP( AST_OP_AND, l, astNewCONSTi( not (ast_bitmaskTB(s->bitfld.bits) shl s->bitfld.bitpos) ) )

	'' This ensures the bitfield is zeroed & clean before the new value
	'' is ORed in below. Since the new value may contain zeroes while the
	'' old values may have one-bits, the OR alone wouldn't necessarily
	'' overwrite the old value.

	'' Truncate r if it's too big, ensuring the OR below won't touch any
	'' other bits outside the target bitfield.
	r = astNewBOP( AST_OP_AND, r, astNewCONSTi( ast_bitmaskTB(s->bitfld.bits) ) )

	'' Move r into position if the bitfield doesn't lie at the beginning of
	'' the accessed field.
	if( s->bitfld.bitpos > 0 ) then
		r = astNewBOP( AST_OP_SHL, r, astNewCONSTi( s->bitfld.bitpos ) )
	end if

	'' OR in the new bitfield value r
	function = astNewBOP( AST_OP_OR, l, r )
end function

private function astAccessBitfield( byval l as ASTNODE ptr ) as ASTNODE ptr
	dim as FBSYMBOL ptr s = any

	''    l<bitfield>
	'' becomes:
	''    (l<int> shr bitpos) and mask

	s = l->subtype
	assert( symbIsBitfield( s ) )

	'' Remap type from bitfield to short/integer/etc, while keeping in
	'' mind that the bitfield may have been casted, so the FIELD's type
	'' can't just be discarded.
	l->dtype = typeJoin( l->dtype, s->typ )
	l->subtype = s->subtype

	'' Shift into position, other bits to the right are shifted out
	if( s->bitfld.bitpos > 0 ) then
		l = astNewBOP( AST_OP_SHR, l, astNewCONSTi( s->bitfld.bitpos ) )
	end if

	'' Mask out other bits to the left
	return astNewBOP( AST_OP_AND, l, astNewCONSTi( ast_bitmaskTB(s->bitfld.bits) ) )
end function

#if __FB_DEBUG__
'' Count the bitfield FIELD nodes in a tree
function astCountBitfields( byval n as ASTNODE ptr ) as integer
	dim as integer count = any

	count = 0

	if( n ) then
		if( astIsBITFIELD( n ) ) then
			count += 1
		end if

		count += astCountBitfields( n->l )
		count += astCountBitfields( n->r )
	end if

	function = count
end function
#endif

'' Remove FIELD nodes that mark bitfield accesses/assignments and add the
'' corresponding code instead. Non-bitfield FIELD nodes stay in,
'' they're used by astProcVectorize().
function astUpdateBitfields( byval n as ASTNODE ptr ) as ASTNODE ptr
	dim as ASTNODE ptr l = any

	'' Shouldn't miss any bitfields
	assert( astCountBitfields( n ) <= ast.bitfieldcount )

	if( ast.bitfieldcount <= 0 ) then
		return n
	end if

	if( n = NULL ) then
		return NULL
	end if

	select case( n->class )
	case AST_NODECLASS_ASSIGN
		'' Assigning to a bitfield?
		if( n->l->class = AST_NODECLASS_FIELD ) then
			if( astGetDataType( n->l->l ) = FB_DATATYPE_BITFIELD ) then
				'' Delete and link out the FIELD
				ast.bitfieldcount -= 1
				astDelNode( n->l )
				n->l = n->l->l

				'' The lhs' type is adjusted, and the new rhs
				'' is returned.
				n->r = astSetBitfield( n->l, n->r )
			end if
		end if

	case AST_NODECLASS_FIELD
		l = n->l
		if( astGetDataType( l ) = FB_DATATYPE_BITFIELD ) then
			l = astAccessBitfield( l )

			'' Delete and link out the FIELD
			ast.bitfieldcount -= 1
			astDelNode( n )
			n = l

			return astUpdateBitfields( n )
		end if

	end select

	n->l = astUpdateBitfields( n->l )
	n->r = astUpdateBitfields( n->r )

	function = n
end function

function astLoadFIELD( byval n as ASTNODE ptr ) as IRVREG ptr
	dim as IRVREG ptr vr = any

	vr = astLoad( n->l )
	astDelNode( n->l )

	if( ast.doemit ) then
		vr->vector = n->vector
	end if

	function = vr
end function

'' Stack operations (l = expression; r = NULL)

function astNewSTACK _
	( _
		byval op as integer, _
		byval l as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr n = any

	if( l = NULL ) then
		return NULL
	end if

	n = astNewNode( AST_NODECLASS_STACK, astGetFullType( l ), NULL )

	n->stack.op = op
	n->l = l

	function = n
end function

function astLoadSTACK( byval n as ASTNODE ptr ) as IRVREG ptr
	dim as ASTNODE ptr l = any
	dim as IRVREG ptr vr = any

	l  = n->l
	if( l = NULL ) then
		return NULL
	end if

	vr = astLoad( l )

	if( ast.doemit ) then
		irEmitSTACK( n->stack.op, vr )
	end if

	astDelNode( l )

	function = vr
end function

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' dumping
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'' The tables below use 'NameInfo' as the struct for
'' information. To keep the size down, the FullName
'' field and value field (unused anyway) are commented
'' out.

type NameInfo
	'' fullname as zstring ptr
	name as const zstring ptr
	'' value as integer
end type

'':::::
private sub dbg_astOutput _
	( _
		byref s as string, _
		byval col as integer, _
		byval just as integer, _
		byval depth as integer = -1 _
	)

	dim pad as integer = any

	select case just
	case -1
		pad = col - len(s)
	case 1
		pad = col - 1
	case else
		pad = col
	end select

	if( depth < 0 ) then
		print space(pad-1); s
	else
		print str(depth); space(pad-1 - len(str(depth)) ); s
	end if

end sub

''
dim shared dbg_astNodeClassNames( 0 to AST_CLASSES-1 ) as NameInfo = _
{ _
	( /' @"AST_NODECLASS_NOP"              , '/ @"NOP"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_LOAD"             , '/ @"LOAD"             /' , 0 '/ ), _
	( /' @"AST_NODECLASS_ASSIGN"           , '/ @"ASSIGN"           /' , 0 '/ ), _
	( /' @"AST_NODECLASS_BOP"              , '/ @"BOP"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_UOP"              , '/ @"UOP"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_CONV"             , '/ @"CONV"             /' , 0 '/ ), _
	( /' @"AST_NODECLASS_ADDROF"           , '/ @"ADDROF"           /' , 0 '/ ), _
	( /' @"AST_NODECLASS_BRANCH"           , '/ @"BRANCH"           /' , 0 '/ ), _
	( /' @"AST_NODECLASS_JMPTB"            , '/ @"JMPTB"            /' , 0 '/ ), _
	( /' @"AST_NODECLASS_CALL"             , '/ @"CALL"             /' , 0 '/ ), _
	( /' @"AST_NODECLASS_CALLCTOR"         , '/ @"CALLCTOR"         /' , 0 '/ ), _
	( /' @"AST_NODECLASS_STACK"            , '/ @"STACK"            /' , 0 '/ ), _
	( /' @"AST_NODECLASS_MEM"              , '/ @"MEM"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_LOOP"             , '/ @"LOOP"             /' , 0 '/ ), _
	( /' @"AST_NODECLASS_COMP"             , '/ @"COMP"             /' , 0 '/ ), _
	( /' @"AST_NODECLASS_LINK"             , '/ @"LINK"             /' , 0 '/ ), _
	( /' @"AST_NODECLASS_CONST"            , '/ @"CONST"            /' , 0 '/ ), _
	( /' @"AST_NODECLASS_VAR"              , '/ @"VAR"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_IDX"              , '/ @"IDX"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_FIELD"            , '/ @"FIELD"            /' , 0 '/ ), _
	( /' @"AST_NODECLASS_DEREF"            , '/ @"DEREF"            /' , 0 '/ ), _
	( /' @"AST_NODECLASS_LABEL"            , '/ @"LABEL"            /' , 0 '/ ), _
	( /' @"AST_NODECLASS_ARG"              , '/ @"ARG"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_OFFSET"           , '/ @"OFFSET"           /' , 0 '/ ), _
	( /' @"AST_NODECLASS_DECL"             , '/ @"DECL"             /' , 0 '/ ), _
	( /' @"AST_NODECLASS_NIDXARRAY"        , '/ @"NIDXARRAY"        /' , 0 '/ ), _
	( /' @"AST_NODECLASS_IIF"              , '/ @"IIF"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_LIT"              , '/ @"LIT"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_ASM"              , '/ @"ASM"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_DATASTMT"         , '/ @"DATASTMT"         /' , 0 '/ ), _
	( /' @"AST_NODECLASS_DBG"              , '/ @"DBG"              /' , 0 '/ ), _
	( /' @"AST_NODECLASS_BOUNDCHK"         , '/ @"BOUNDCHK"         /' , 0 '/ ), _
	( /' @"AST_NODECLASS_PTRCHK"           , '/ @"PTRCHK"           /' , 0 '/ ), _
	( /' @"AST_NODECLASS_SCOPEBEGIN"       , '/ @"SCOPEBEGIN"       /' , 0 '/ ), _
	( /' @"AST_NODECLASS_SCOPEEND"         , '/ @"SCOPEEND"         /' , 0 '/ ), _
	( /' @"AST_NODECLASS_SCOPE_BREAK"      , '/ @"SCOPE_BREAK"      /' , 0 '/ ), _
	( /' @"AST_NODECLASS_TYPEINI"          , '/ @"TYPEINI"          /' , 0 '/ ), _
	( /' @"AST_NODECLASS_TYPEINI_PAD"      , '/ @"TYPEINI_PAD"      /' , 0 '/ ), _
	( /' @"AST_NODECLASS_TYPEINI_ASSIGN"   , '/ @"TYPEINI_ASSIGN"   /' , 0 '/ ), _
	( /' @"AST_NODECLASS_TYPEINI_CTORCALL" , '/ @"TYPEINI_CTORCALL" /' , 0 '/ ), _
	( /' @"AST_NODECLASS_TYPEINI_CTORLIST" , '/ @"TYPEINI_CTORLIST" /' , 0 '/ ), _
	( /' @"AST_NODECLASS_TYPEINI_SCOPEINI" , '/ @"TYPEINI_SCOPEINI" /' , 0 '/ ), _
	( /' @"AST_NODECLASS_TYPEINI_SCOPEEND" , '/ @"TYPEINI_SCOPEEND" /' , 0 '/ ), _
	( /' @"AST_NODECLASS_PROC"             , '/ @"PROC"             /' , 0 '/ ) _
}

''
dim shared dbg_astNodeOpNames( 0 to AST_OPCODES - 1 ) as NameInfo = _
{ _
	( /' @"AST_OP_ASSIGN"          , '/ @"="            /' , 0 '/ ), _
	( /' @"AST_OP_ADD_SELF"        , '/ @"+="           /' , 0 '/ ), _
	( /' @"AST_OP_SUB_SELF"        , '/ @"-="           /' , 0 '/ ), _
	( /' @"AST_OP_MUL_SELF"        , '/ @"*="           /' , 0 '/ ), _
	( /' @"AST_OP_DIV_SELF"        , '/ @"/="           /' , 0 '/ ), _
	( /' @"AST_OP_INTDIV_SELF"     , '/ @"\="           /' , 0 '/ ), _
	( /' @"AST_OP_MOD_SELF"        , '/ @"MOD="         /' , 0 '/ ), _
	( /' @"AST_OP_AND_SELF"        , '/ @"AND="         /' , 0 '/ ), _
	( /' @"AST_OP_OR_SELF"         , '/ @"OR="          /' , 0 '/ ), _
	( /' @"AST_OP_ANDALSO_SELF"    , '/ @"ANDALSO="     /' , 0 '/ ), _
	( /' @"AST_OP_ORELSE_SELF"     , '/ @"ORELSE="      /' , 0 '/ ), _
	( /' @"AST_OP_XOR_SELF"        , '/ @"XOR="         /' , 0 '/ ), _
	( /' @"AST_OP_EQV_SELF"        , '/ @"EQV="         /' , 0 '/ ), _
	( /' @"AST_OP_IMP_SELF"        , '/ @"IMP="         /' , 0 '/ ), _
	( /' @"AST_OP_SHL_SELF"        , '/ @"SHL="         /' , 0 '/ ), _
	( /' @"AST_OP_SHR_SELF"        , '/ @"SHR="         /' , 0 '/ ), _
	( /' @"AST_OP_POW_SELF"        , '/ @"^="           /' , 0 '/ ), _
	( /' @"AST_OP_CONCAT_SELF"     , '/ @"&="           /' , 0 '/ ), _
	( /' @"AST_OP_NEW_SELF"        , '/ @"new="         /' , 0 '/ ), _
	( /' @"AST_OP_NEW_VEC_SELF"    , '/ @"new[]="       /' , 0 '/ ), _
	( /' @"AST_OP_DEL_SELF"        , '/ @"del="         /' , 0 '/ ), _
	( /' @"AST_OP_DEL_VEC_SELF"    , '/ @"del[]="       /' , 0 '/ ), _
	( /' @"AST_OP_ADDROF"          , '/ @"ADDROF"       /' , 0 '/ ), _
	( /' @"AST_OP_PTRINDEX"        , '/ @"PTRINDEX"     /' , 0 '/ ), _
	( /' @"AST_OP_FOR"             , '/ @"FOR"          /' , 0 '/ ), _
	( /' @"AST_OP_STEP"            , '/ @"STEP"         /' , 0 '/ ), _
	( /' @"AST_OP_NEXT"            , '/ @"NEXT"         /' , 0 '/ ), _
	( /' @"AST_OP_CAST"            , '/ @"CAST"         /' , 0 '/ ), _
	( /' @"AST_OP_ADD"             , '/ @"+"            /' , 0 '/ ), _
	( /' @"AST_OP_SUB"             , '/ @"-"            /' , 0 '/ ), _
	( /' @"AST_OP_MUL"             , '/ @"*"            /' , 0 '/ ), _
	( /' @"AST_OP_DIV"             , '/ @"/"            /' , 0 '/ ), _
	( /' @"AST_OP_INTDIV"          , '/ @"\"            /' , 0 '/ ), _
	( /' @"AST_OP_MOD"             , '/ @"MOD"          /' , 0 '/ ), _
	( /' @"AST_OP_AND"             , '/ @"AND"          /' , 0 '/ ), _
	( /' @"AST_OP_OR"              , '/ @"OR"           /' , 0 '/ ), _
	( /' @"AST_OP_ANDALSO"         , '/ @"ANDALSO"      /' , 0 '/ ), _
	( /' @"AST_OP_ORELSE"          , '/ @"ORELSE"       /' , 0 '/ ), _
	( /' @"AST_OP_XOR"             , '/ @"XOR"          /' , 0 '/ ), _
	( /' @"AST_OP_EQV"             , '/ @"EQV"          /' , 0 '/ ), _
	( /' @"AST_OP_IMP"             , '/ @"IMP"          /' , 0 '/ ), _
	( /' @"AST_OP_SHL"             , '/ @"SHL"          /' , 0 '/ ), _
	( /' @"AST_OP_SHR"             , '/ @"SHR"          /' , 0 '/ ), _
	( /' @"AST_OP_POW"             , '/ @"^"            /' , 0 '/ ), _
	( /' @"AST_OP_CONCAT"          , '/ @"&"            /' , 0 '/ ), _
	( /' @"AST_OP_EQ"              , '/ @"=="           /' , 0 '/ ), _
	( /' @"AST_OP_GT"              , '/ @">"            /' , 0 '/ ), _
	( /' @"AST_OP_LT"              , '/ @"<"            /' , 0 '/ ), _
	( /' @"AST_OP_NE"              , '/ @"<>"           /' , 0 '/ ), _
	( /' @"AST_OP_GE"              , '/ @">="           /' , 0 '/ ), _
	( /' @"AST_OP_LE"              , '/ @"<="           /' , 0 '/ ), _
	( /' @"AST_OP_IS"              , '/ @"IS"           /' , 0 '/ ), _
	( /' @"AST_OP_NOT"             , '/ @"NOT"          /' , 0 '/ ), _
	( /' @"AST_OP_PLUS"            , '/ @"+"            /' , 0 '/ ), _
	( /' @"AST_OP_NEG"             , '/ @"NEG"          /' , 0 '/ ), _
	( /' @"AST_OP_HADD"            , '/ @"HADD"         /' , 0 '/ ), _
	( /' @"AST_OP_ABS"             , '/ @"ABS"          /' , 0 '/ ), _
	( /' @"AST_OP_SGN"             , '/ @"SGN"          /' , 0 '/ ), _
	( /' @"AST_OP_SIN"             , '/ @"SIN"          /' , 0 '/ ), _
	( /' @"AST_OP_ASIN"            , '/ @"ASIN"         /' , 0 '/ ), _
	( /' @"AST_OP_COS"             , '/ @"COS"          /' , 0 '/ ), _
	( /' @"AST_OP_ACOS"            , '/ @"ACOS"         /' , 0 '/ ), _
	( /' @"AST_OP_TAN"             , '/ @"TAN"          /' , 0 '/ ), _
	( /' @"AST_OP_ATAN"            , '/ @"ATAN"         /' , 0 '/ ), _
	( /' @"AST_OP_ATAN2"           , '/ @"ATAN2"        /' , 0 '/ ), _
	( /' @"AST_OP_SQRT"            , '/ @"SQRT"         /' , 0 '/ ), _
	( /' @"AST_OP_RSQRT"           , '/ @"RSQRT"        /' , 0 '/ ), _
	( /' @"AST_OP_RCP"             , '/ @"RCP"          /' , 0 '/ ), _
	( /' @"AST_OP_LOG"             , '/ @"LOG"          /' , 0 '/ ), _
	( /' @"AST_OP_EXP"             , '/ @"EXP"          /' , 0 '/ ), _
	( /' @"AST_OP_FLOOR"           , '/ @"FLOOR"        /' , 0 '/ ), _
	( /' @"AST_OP_FIX"             , '/ @"FIX"          /' , 0 '/ ), _
	( /' @"AST_OP_FRAC"            , '/ @"FRAC"         /' , 0 '/ ), _
	( /' @"AST_OP_CONVFD2FS"       , '/ @"CONVFD2FS"    /' , 0 '/ ), _
	( /' @"AST_OP_SWZREP"          , '/ @"SWZREP"       /' , 0 '/ ), _
	( /' @"AST_OP_DEREF"           , '/ @"DEREF"        /' , 0 '/ ), _
	( /' @"AST_OP_FLDDEREF"        , '/ @"FLDDEREF"     /' , 0 '/ ), _
	( /' @"AST_OP_NEW"             , '/ @"NEW"          /' , 0 '/ ), _
	( /' @"AST_OP_NEW_VEC"         , '/ @"NEW_VEC"      /' , 0 '/ ), _
	( /' @"AST_OP_DEL"             , '/ @"DEL"          /' , 0 '/ ), _
	( /' @"AST_OP_DEL_VEC"         , '/ @"DEL_VEC"      /' , 0 '/ ), _
	( /' @"AST_OP_TOINT"           , '/ @"TOINT"        /' , 0 '/ ), _
	( /' @"AST_OP_TOFLT"           , '/ @"TOFLT"        /' , 0 '/ ), _
	( /' @"AST_OP_LOAD"            , '/ @"LOAD"         /' , 0 '/ ), _
	( /' @"AST_OP_LOADRES"         , '/ @"LOADRES"      /' , 0 '/ ), _
	( /' @"AST_OP_SPILLREGS"       , '/ @"SPILLREGS"    /' , 0 '/ ), _
	( /' @"AST_OP_PUSH"            , '/ @"PUSH"         /' , 0 '/ ), _
	( /' @"AST_OP_POP"             , '/ @"POP"          /' , 0 '/ ), _
	( /' @"AST_OP_PUSHUDT"         , '/ @"PUSHUDT"      /' , 0 '/ ), _
	( /' @"AST_OP_STACKALIGN"      , '/ @"STACKALIGN"   /' , 0 '/ ), _
	( /' @"AST_OP_JEQ"             , '/ @"JEQ"          /' , 0 '/ ), _
	( /' @"AST_OP_JGT"             , '/ @"JGT"          /' , 0 '/ ), _
	( /' @"AST_OP_JLT"             , '/ @"JLT"          /' , 0 '/ ), _
	( /' @"AST_OP_JNE"             , '/ @"JNE"          /' , 0 '/ ), _
	( /' @"AST_OP_JGE"             , '/ @"JGE"          /' , 0 '/ ), _
	( /' @"AST_OP_JLE"             , '/ @"JLE"          /' , 0 '/ ), _
	( /' @"AST_OP_JMP"             , '/ @"JMP"          /' , 0 '/ ), _
	( /' @"AST_OP_CALL"            , '/ @"CALL"         /' , 0 '/ ), _
	( /' @"AST_OP_LABEL"           , '/ @"LABEL"        /' , 0 '/ ), _
	( /' @"AST_OP_RET"             , '/ @"RET"          /' , 0 '/ ), _
	( /' @"AST_OP_CALLFUNCT"       , '/ @"CALLFUNCT"    /' , 0 '/ ), _
	( /' @"AST_OP_CALLPTR"         , '/ @"CALLPTR"      /' , 0 '/ ), _
	( /' @"AST_OP_JUMPPTR"         , '/ @"JUMPPTR"      /' , 0 '/ ), _
	( /' @"AST_OP_MEMMOVE"         , '/ @"MEMMOVE"      /' , 0 '/ ), _
	( /' @"AST_OP_MEMSWAP"         , '/ @"MEMSWAP"      /' , 0 '/ ), _
	( /' @"AST_OP_MEMCLEAR"        , '/ @"MEMCLEAR"     /' , 0 '/ ), _
	( /' @"AST_OP_STKCLEAR"        , '/ @"STKCLEAR"     /' , 0 '/ ), _
	( /' @"AST_OP_DBG_LINEINI"     , '/ @"DBG_LINEINI"  /' , 0 '/ ), _
	( /' @"AST_OP_DBG_LINEEND"     , '/ @"DBG_LINEEND"  /' , 0 '/ ), _
	( /' @"AST_OP_DBG_SCOPEINI"    , '/ @"DBG_SCOPEINI" /' , 0 '/ ), _
	( /' @"AST_OP_DBG_SCOPEEND"    , '/ @"BDG_SCOPEEND" /' , 0 '/ ), _
	( /' @"AST_OP_LIT_COMMENT"     , '/ @"LIT_COMMENT"  /' , 0 '/ ), _
	( /' @"AST_OP_LIT_ASM"         , '/ @"LIT_ASM"      /' , 0 '/ ), _
	( /' @"AST_OP_TOSIGNED"        , '/ @"TOSIGNED"     /' , 0 '/ ), _
	( /' @"AST_OP_TOUNSIGNED"      , '/ @"TOUNSIGNED"   /' , 0 '/ ) _
}

function astDumpOp( byval op as AST_OP ) as string
	if(( op > AST_OPCODES - 1 ) or ( op < 0 )) then
		return "OP:" + str(op)
	end if
	return *dbg_astNodeOpNames( op ).name
end function

'':::::
private function hAstNodeClassToStr _
	( _
		byval c as AST_NODECLASS _
	) as string

	if(( c > AST_CLASSES - 1 ) or ( c < 0 )) then
		return "CLASS:" + str(c)
	end if

	return *dbg_astNodeClassNames( c ).name

end function

'':::::
private function hSymbToStr _
	( _
		byval s as FBSYMBOL ptr _
	) as string

	if( s = NULL ) then return ""

	if( s->id.name ) then
		return *(s->id.name)
	elseif( s->id.alias ) then
		return *(s->id.alias)
	end if
end function

'':::::
private function hAstNodeToStr _
	( _
		byval n as ASTNODE ptr _
	) as string

	select case as const n->class
	case AST_NODECLASS_BOP
		return astDumpOp( n->op.op ) & " =-= " & hSymbToStr( n->op.ex )

	case AST_NODECLASS_UOP
		return astDumpOp( n->op.op )

	case AST_NODECLASS_CONST
		if( typeGetClass( n->dtype ) = FB_DATACLASS_FPOINT ) then
			return str( astConstGetFloat( n ) )
		end if
		return str( astConstGetInt( n ) )

	case AST_NODECLASS_VAR
		return "VAR( " & *iif( n->sym, symbGetName( n->sym ), @"<NULL>" ) & " )"

	case AST_NODECLASS_DECL
		if( n->sym ) then
			return "DECL( " & *symbGetName( n->sym ) & " )"
		end if
		return "DECL"

	case AST_NODECLASS_CALL
		return "CALL( " & *symbGetName( n->sym ) & " )"

	case AST_NODECLASS_LABEL
		return "LABEL: " & hSymbToStr( n->sym )

	case AST_NODECLASS_BRANCH
		return "BRANCH: " & astDumpOp( n->op.op ) & " " & hSymbToStr( n->op.ex )

	case AST_NODECLASS_SCOPEBEGIN
		return "SCOPEBEGIN: " & hSymbToStr( n->sym )

	case else
		return hAstNodeClassToStr( n->class )
	end select

end function

'':::::
private sub astDumpTreeEx _
	( _
		byval n as ASTNODE ptr, _
		byval col as integer, _
		byval just as integer, _
		byval depth as integer _
	)

	if( col <= 4 or col >= 76 ) then
		col = 40
	end if

	if( n = NULL ) then
		print "<NULL>"
		exit sub
	end if

	dim as string s
	's += "[" + hex( n, 8 ) + "] "
	s += hAstNodeToStr( n )
	's += " " + typeDump( n->dtype, n->subtype )
	dbg_astOutput( s, col, just, depth )

	depth += 1

	if( n->l <> NULL ) then
		if( n->r <> NULL ) then
			dbg_astOutput( "/ \", col-2, 0 )
		else
			dbg_astOutput( "/", col-2, 0 )
		end if
	elseif( n->r <> NULL ) then
		dbg_astOutput( "  \", col-2, 0 )
	else
		dbg_astOutput( "", 0, 0 )
	end if

	if( n->l <> NULL ) then
		astDumpTreeEx( n->l, col-2, -1, depth )
	end if
	if( n->r <> NULL ) then
		astDumpTreeEx( n->r, col+2, 1, depth )
	end if

end sub

'':::::
sub astDumpTree _
	( _
		byval n as ASTNODE ptr, _
		byval col as integer _
	)

	astDumpTreeEx( n, col, -1, 0 )

end sub

''::::
sub astDumpList _
	( _
		byval n as ASTNODE ptr, _
		byval col as integer _
	)

	do while( n <> NULL )
		astDumpTree( n, col )
		n = n->next
	loop

end sub

#if __FB_DEBUG__
function astDumpInline( byval n as ASTNODE ptr ) as string
	static reclevel as integer

	reclevel += 1

	dim s as string
	if( n = NULL ) then
		s = "<NULL>"
	else
		s += hAstNodeClassToStr( n->class )
		's += typeDump( n->dtype, n->subtype )

		var have_data = (n->sym <> NULL) or (n->l <> NULL) or (n->r <> NULL)
		select case as const( n->class )
		case AST_NODECLASS_BOP, AST_NODECLASS_UOP, AST_NODECLASS_CONST
			have_data or= TRUE
		end select

		if( have_data ) then
			s += "( "
		end if

		select case as const( n->class )
		case AST_NODECLASS_BOP, AST_NODECLASS_UOP
			s += astDumpOp( n->op.op ) + ", "
		case AST_NODECLASS_CONST
			if( typeGetClass( n->dtype ) = FB_DATACLASS_FPOINT ) then
				s += str( astConstGetFloat( n ) ) + ", "
			else
				s += str( astConstGetInt( n ) ) + ", "
			end if
		end select

		if( n->sym ) then
			s += *symbGetName( n->sym ) + ", "
		end if
		if( n->l ) then
			s += astDumpInline( n->l ) + ", "
		end if
		if( n->r ) then
			s += astDumpInline( n->r ) + ", "
		end if

		if( have_data ) then
			if( right( s, 2 ) = ", " ) then
				s = left( s, len( s ) - 2 )
			end if
			s += " )"
		end if
	end if

	reclevel -= 1

	function = s
end function
#endif
