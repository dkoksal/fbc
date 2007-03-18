/*
 *  libgfx2 - FreeBASIC's alternative gfx library
 *	Copyright (C) 2005 Angelo Mottola (a.mottola@libero.it)
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
 * put_alpha.c -- ALPHA drawing method for PUT statement
 *
 * chng: mar/2007 written [lillo]
 *
 */

#include "fb_gfx.h"


extern void fb_hPutPSetC(unsigned char *src, unsigned char *dest, int w, int h, int src_pitch, int dest_pitch, int alpha, BLENDER *blender, void *param);

#if defined(TARGET_X86)

#include "fb_gfx_mmx.h"

extern void fb_hPutPSetMMX(unsigned char *src, unsigned char *dest, int w, int h, int src_pitch, int dest_pitch, int alpha, BLENDER *blender, void *param);
extern void fb_hPutAlpha4MMX(unsigned char *src, unsigned char *dest, int w, int h, int src_pitch, int dest_pitch, int alpha, BLENDER *blender, void *param);

#endif


/*:::::*/
static void fb_hPutAlpha4C(unsigned char *src, unsigned char *dest, int w, int h, int src_pitch, int dest_pitch, int alpha, BLENDER *blender, void *param)
{
	unsigned int *s = (unsigned int *)src;
	unsigned int *d, sc, dc, a, drb, dga, srb, sga;
	int x;
	
	src_pitch = (src_pitch >> 2) - w;
	for (; h; h--) {
		d = (unsigned int *)dest;
		for (x = w; x; x--) {
			sc = *s++;
			dc = *d;
			a = (sc >> 24);
			srb = sc & MASK_RB_32;
			sga = sc & MASK_GA_32;
			drb = dc & MASK_RB_32;
			dga = dc & MASK_GA_32;
			srb = ((srb - drb) * a) >> 8;
			sga = ((sga - dga) >> 8) * a;
			*d++ = ((drb + srb) & MASK_RB_32) | ((dga + sga) & MASK_GA_32);
		}
		s += src_pitch;
		dest += dest_pitch;
	}
}


/*:::::*/
void fb_hPutAlpha(unsigned char *src, unsigned char *dest, int w, int h, int src_pitch, int dest_pitch, int alpha, BLENDER *blender, void *param)
{
	PUTTER *all_putters[] = {
		fb_hPutPSetC, fb_hPutPSetC, NULL, fb_hPutAlpha4C,
#if defined(TARGET_X86)
		fb_hPutPSetMMX, fb_hPutPSetMMX, NULL, fb_hPutAlpha4MMX,
#endif
	}, *putter;
	FB_GFXCTX *context = fb_hGetContext();
	
	if (!context->putter[PUT_MODE_ALPHA]) {
#if defined(TARGET_X86)
		if (__fb_gfx->flags & HAS_MMX)
			context->putter[PUT_MODE_ALPHA] = &all_putters[4];
		else
#endif
			context->putter[PUT_MODE_ALPHA] = &all_putters[0];
	}
	putter = context->putter[PUT_MODE_ALPHA][context->target_bpp - 1];
	
	putter(src, dest, w, h, src_pitch, dest_pitch, alpha, blender, param);
}