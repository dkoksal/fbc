/*
 *  libfb - FreeBASIC's runtime library
 *	Copyright (C) 2004-2005 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * io_write.c -- write [#] functions
 *
 * chng: nov/2004 written [v1ctor]
 *
 */

#include <stdio.h>
#include "fb.h"

#define FB_WRITENUM(fnum, val, mask, type) 			\
    char buffer[80];									\
    													\
    if( mask & FB_PRINT_NEWLINE )           			\
    	sprintf( buffer, type "\n", val );       		\
    else												\
    	sprintf( buffer, type ",", val );               \
    													\
    if( fnum == 0 )									\
    	fb_hPrintBuffer( buffer, mask );				\
    else												\
    	fb_hFilePrintBuffer( fnum, buffer );


#define FB_WRITESTR(fnum, val, mask, type) 			\
    char buffer[80*25+1];								\
    													\
    if( mask & FB_PRINT_NEWLINE )           			\
    	sprintf( buffer, type "\n", val );       		\
    else												\
    	sprintf( buffer, type ",", val );               \
    													\
    if( fnum == 0 )									\
    	fb_hPrintBuffer( buffer, mask );				\
    else												\
    	fb_hFilePrintBuffer( fnum, buffer );


/*:::::*/
__stdcall void fb_WriteVoid ( int fnum, int mask )
{
    char *buffer;

    if( mask & FB_PRINT_NEWLINE )
    	buffer = "\n";
    else if( mask & FB_PRINT_PAD )
    	buffer = "%-14";
    else
    	buffer = NULL;

    if( buffer != NULL )
    {
    	if( fnum == 0 )
    		fb_hPrintBuffer( buffer, mask );
    	else
    		fb_hFilePrintBuffer( fnum, buffer );
    }
}

/*:::::*/
__stdcall void fb_WriteByte ( int fnum, char val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%d" )
}

/*:::::*/
__stdcall void fb_WriteUByte ( int fnum, unsigned char val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%u" )
}

/*:::::*/
__stdcall void fb_WriteShort ( int fnum, short val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%hd" )
}

/*:::::*/
__stdcall void fb_WriteUShort ( int fnum, unsigned short val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%hu" )
}

/*:::::*/
__stdcall void fb_WriteInt ( int fnum, int val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%d" )
}

/*:::::*/
__stdcall void fb_WriteUInt ( int fnum, unsigned int val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%u" )
}

/*:::::*/
__stdcall void fb_WriteSingle ( int fnum, float val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%g" )
}

/*:::::*/
__stdcall void fb_WriteDouble ( int fnum, double val, int mask )
{
    FB_WRITENUM( fnum, val, mask, "%lg" )
}

/*:::::*/
__stdcall void fb_WriteString ( int fnum, FBSTRING *s, int mask )
{
    FB_WRITESTR( fnum, s->data, mask, "\"%s\"" )

	/* del if temp */
	fb_hStrDelTemp( s );
}
