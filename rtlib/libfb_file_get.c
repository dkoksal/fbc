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
 *	file_get - get # function
 *
 * chng: oct/2004 written [marzec/v1ctor]
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include "fb.h"
#include "fb_rterr.h"


/*:::::*/
__stdcall int fb_FileGet( int fnum, long pos, void* value, unsigned int valuelen )
{
	int i, result;

	if( fnum < 1 || fnum > FB_MAX_FILES )
		return FB_RTERROR_ILLEGALFUNCTIONCALL;

	if( fb_fileTB[fnum-1].f == NULL )
		return FB_RTERROR_ILLEGALFUNCTIONCALL;

	/* seek to newpos */
	if( pos > 0 )
	{
		/* if in random mode, seek in reclen's */
		if( fb_fileTB[fnum-1].mode == FB_FILE_MODE_RANDOM )
			pos = (pos-1) * fb_fileTB[fnum-1].len;
		else
			--pos;

		result = fseek( fb_fileTB[fnum-1].f, pos, SEEK_SET );
		if( result != 0 )
			return FB_RTERROR_FILEIO;
	}

	/* do read */
	if( fread( value, 1, valuelen, fb_fileTB[fnum-1].f ) != valuelen )
	{
		/* fill with nulls if at eof */
		for( i = 0; i < valuelen; i++ )
			*(char *)value++ = 0;
		/*return FB_FALSE*/;						/* do nothing, not an error */
	}

    /* if in random mode, reads must be of reclen */
	if( fb_fileTB[fnum-1].mode == FB_FILE_MODE_RANDOM )
	{
		valuelen = fb_fileTB[fnum-1].len - valuelen;
		if( valuelen > 0 )
			fseek( fb_fileTB[fnum-1].f, valuelen, SEEK_CUR );
	}

	return FB_RTERROR_OK;
}

/*:::::*/
__stdcall int fb_FileGetStr( int fnum, long pos, FBSTRING *str )
{
	int result, len, rlen, i;

	if( fnum < 1 || fnum > FB_MAX_FILES )
		return FB_RTERROR_ILLEGALFUNCTIONCALL;

	if( fb_fileTB[fnum-1].f == NULL )
		return FB_RTERROR_ILLEGALFUNCTIONCALL;

	/* seek to newpos */
	if( pos > 0 )
	{
		/* if in random mode, seek in reclen's */
		if( fb_fileTB[fnum-1].mode == FB_FILE_MODE_RANDOM )
			pos = (pos-1) * fb_fileTB[fnum-1].len;
		else
			--pos;

		result = fseek( fb_fileTB[fnum-1].f, pos, SEEK_SET );
		if( result != 0 )
			return FB_RTERROR_FILEIO;
	}

	len = FB_STRSIZE( str );

	/* do read */
	rlen = fread( str->data, 1, len, fb_fileTB[fnum-1].f );
	if( rlen != len )
	{
		/* fill with nulls if at eof */
		for( i = rlen; i <= len; i++ )
			str->data[i] = '\0';
		/*return FB_FALSE*/;						/* do nothing, not an error */
	}

    /* if in random mode, reads must be of reclen */
	if( fb_fileTB[fnum-1].mode == FB_FILE_MODE_RANDOM )
	{
		len = fb_fileTB[fnum-1].len - len;
		if( len > 0 )
			fseek( fb_fileTB[fnum-1].f, len, SEEK_CUR );
	}

	/* del if temp */
	fb_hStrDelTemp( str );						/* will free the temp desc if fix-len passed */

	return FB_RTERROR_OK;
}

