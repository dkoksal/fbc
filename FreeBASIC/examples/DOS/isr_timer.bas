#include "dos/dpmi.bi"

type FnIntHandler as function cdecl( byval as uinteger) as integer

declare function fb_isr_set cdecl alias "fb_isr_set"( _
	byval irq_number as uinteger, _
    byval pfnIntHandler as FnIntHandler ptr, _
    byval size as uinteger, _
    byval stack_size as uinteger = 0) as integer

declare function fb_isr_reset cdecl alias "fb_isr_reset"( _
	byval irq_number as uinteger ) as integer

declare function fb_isr_get cdecl alias "fb_isr_get"( _
	byval irq_number as uinteger ) as FnIntHandler

declare function fb_dos_lock_mem cdecl alias "fb_dos_lock_mem"( _
	byval as any ptr, byval as uinteger ) as integer
declare function fb_dos_unlock_mem cdecl alias "fb_dos_unlock_mem"( _
	byval as any ptr, byval as uinteger ) as integer


dim shared isr_data_start as byte
dim shared timer_ticks as integer
dim shared old_isr as FnIntHandler
dim shared isr_data_end as byte

private function isr_timer cdecl( byval irq_number as uinteger) as integer
    timer_ticks += 1
    if old_isr<>0 then
        function = old_isr( irq_number )
    else
        function = 0   ' FALSE = we don't want to abort ISR handling
               '         IOW: call the old ISR handler
    end if
end function
private sub isr_timer_end cdecl()
end sub

if fb_dos_lock_mem( @isr_data_start, @isr_data_end - @isr_data_start )<>0 then
    print "Failed to lock data"
    end 1
end if

dim as byte ptr ptr_end = cptr( byte ptr, @isr_timer_end )
dim as byte ptr ptr_start = cptr( byte ptr, @isr_timer )
if not fb_isr_set( 0, @isr_timer, ptr_end - ptr_start, 16384 ) then
    print "Failed to lock ISR"
    end 1
end if

print "Press ENTER to stop counting timer ticks"

while len(inkey$)=0: sleep 100: wend

fb_isr_reset( 0 )

print timer_ticks
end
