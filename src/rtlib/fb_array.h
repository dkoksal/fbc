typedef struct _FBARRAYDIM {
	size_t elements;
	ssize_t lbound;
	ssize_t ubound;
} FBARRAYDIM;

typedef struct _FBARRAY {
	void           *data;        /* ptr + diff, must be at ofs 0! */
	void           *ptr;
	size_t          size;
	size_t          element_len;
	size_t          dimensions;
	FBARRAYDIM      dimTB[1];    /* dimtb[dimensions] */
} FBARRAY;

/*!!!REMOVEME!!!*/
typedef struct _FB_ARRAY_TMPDESC {
    FB_LISTELEM     elem;

    FBARRAY         array;
    FBARRAYDIM      dimTB[FB_MAXDIMENSIONS-1];
} FB_ARRAY_TMPDESC;
/*!!!REMOVEME!!!*/

typedef void (*FB_DEFCTOR) ( const void *this_ );
typedef void (*FB_DTORMULT) ( FBARRAY *array, FB_DEFCTOR dtor, size_t base_idx );


#define FB_ARRAY_SETDESC(_array, _elen, _dims, _size, _diff)          \
    do {                                                              \
        _array->element_len = _elen;                                  \
        _array->dimensions  = _dims;                                  \
        _array->size        = _size;                                  \
                                                                      \
        if( _array->ptr != NULL )                                     \
            _array->data = ((unsigned char*) _array->ptr) + (_diff);  \
        else                                                          \
            _array->data = NULL;                                      \
    } while (0)

FBCALL void *fb_ArrayBoundChk
	(
		ssize_t idx,
		ssize_t lbound,
		ssize_t ubound,
		int linenum,
		const char *fname
	);

FBCALL void *fb_ArraySngBoundChk
	(
		size_t idx,
		size_t ubound,
		int linenum,
		const char *fname
	);

       void       fb_hArrayCtorObj     ( FBARRAY *array, FB_DEFCTOR ctor, size_t base_idx );
       void       fb_hArrayDtorObj     ( FBARRAY *array, FB_DEFCTOR dtor, size_t base_idx );
       void       fb_hArrayDtorStr     ( FBARRAY *array, FB_DEFCTOR dtor, size_t base_idx );
FBCALL void       fb_ArrayDestructObj  ( FBARRAY *array, FB_DEFCTOR dtor );
FBCALL void       fb_ArrayDestructStr  ( FBARRAY *array );
FBCALL int        fb_ArrayClear        ( FBARRAY *array, int isvarlen );
FBCALL int        fb_ArrayClearObj     ( FBARRAY *array, FB_DEFCTOR ctor, FB_DEFCTOR dtor, int dofill );
FBCALL int        fb_ArrayErase        ( FBARRAY *array, int isvarlen );
FBCALL int        fb_ArrayEraseObj     ( FBARRAY *array, FB_DEFCTOR dtor );
FBCALL void       fb_ArrayStrErase     ( FBARRAY *array );
       int        fb_ArrayRedim        ( FBARRAY *array, size_t element_len, int preserve, size_t dimensions, ... );
       int        fb_ArrayRedimEx      ( FBARRAY *array, size_t element_len, int doclear, int isvarlen, size_t dimensions, ... );
       int        fb_ArrayRedimObj     ( FBARRAY *array, size_t element_len, FB_DEFCTOR ctor, FB_DEFCTOR dtor, size_t dimensions, ... );
       int        fb_ArrayRedimPresv   ( FBARRAY *array, size_t element_len, int preserve, size_t dimensions, ... );
       int        fb_ArrayRedimPresvEx ( FBARRAY *array, size_t element_len, int doclear, int isvarlen, size_t dimensions, ... );
       int        fb_ArrayRedimPresvObj( FBARRAY *array, size_t element_len, FB_DEFCTOR ctor, FB_DEFCTOR dtor, size_t dimensions, ... );
FBCALL void       fb_ArrayResetDesc    ( FBARRAY *array );
FBCALL ssize_t    fb_ArrayLBound       ( FBARRAY *array, ssize_t dimension );
FBCALL ssize_t    fb_ArrayUBound       ( FBARRAY *array, ssize_t dimension );
       size_t     fb_hArrayCalcElements( size_t dimensions, const ssize_t *lboundTB, const ssize_t *uboundTB );
       ssize_t    fb_hArrayCalcDiff    ( size_t dimensions, const ssize_t *lboundTB, const ssize_t *uboundTB );

int fb_hArrayAlloc
	(
		FBARRAY *array,
		size_t element_len,
		int doclear,
		FB_DEFCTOR ctor,
		size_t dimensions,
		va_list ap
	);

int fb_hArrayRealloc
	(
		FBARRAY *array,
		size_t element_len,
		int doclear,
		FB_DEFCTOR ctor,
		FB_DTORMULT dtor_mult,
		FB_DEFCTOR dtor,
		size_t dimensions,
		va_list ap
	);
