#include "fbcu.bi"

namespace fbc_tests.ns.var_named_as_udt

type UDT1
	i as integer
end type

namespace ns1
	type B
		i as integer
		declare function foo( ) as integer
	end type

	function B.foo( ) as integer
		function = i
	end function
end namespace

sub test cdecl( )
	'' Allowed because UDT1 is a POD UDT, not a "class"
	dim udt1 as UDT1 = ( 123 )
	CU_ASSERT( udt1.i = 123 )
	udt1.i = 456
	CU_ASSERT( udt1.i = 456 )

	'' This works because it's a different namespace,
	'' even though B is a class
	using ns1
	dim b as B = ( 123 )
	CU_ASSERT( b.i = 123 )
	b.i = 456
	CU_ASSERT( b.foo( ) = 456 )
end sub

private sub ctor( ) constructor
	fbcu.add_suite( "tests/namespace/var-named-as-udt" )
	fbcu.add_test( "test", @test )
end sub

end namespace
