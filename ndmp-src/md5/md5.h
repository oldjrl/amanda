/* MD5.H - header file for MD5C.C
 */

/* Copyright (C) 1991-2, RSA Data Security, Inc. Created 1991. All
rights reserved.

License to copy and use this software is granted provided that it
is identified as the "RSA Data Security, Inc. MD5 Message-Digest
Algorithm" in all material mentioning or referencing this software
or this function.

License is also granted to make and use derivative works provided
that such works are identified as "derived from the RSA Data
Security, Inc. MD5 Message-Digest Algorithm" in all material
mentioning or referencing the derived work.

RSA Data Security, Inc. makes no representations concerning either
the merchantability of this software or the suitability of this
software for any particular purpose. It is provided "as is"
without express or implied warranty of any kind.

These notices must be retained in any copies of any part of this
documentation and/or software.
 */

/* PROTOTYPES should be set to one if and only if the compiler supports
  function argument prototyping.
The following makes PROTOTYPES default to 0 if it has not already
  been defined with C compiler flags.
 */
#ifndef PROTOTYPES
#define PROTOTYPES 1
#endif

#define MD5_LEN 16

/* POINTER defines a generic pointer type */
typedef unsigned char *POINTER;

/* UINT2 defines a two byte word */
typedef unsigned short int UINT2;

#ifdef	i386
/* UINT4 defines a four byte word */
typedef unsigned long int UINT4;
#else
/* UINT4 defines a four byte word */
typedef unsigned int UINT4;
#endif

/* PROTO_LIST is defined depending on how PROTOTYPES is defined above.
If using PROTOTYPES, then PROTO_LIST returns the list, otherwise it
  returns an empty list.
 */
#if PROTOTYPES
#define PROTO_LIST(list) list
#else
#define PROTO_LIST(list) ()
#endif

#if AMANDA_MD5_PKG_ENUM == 4	/* AMANDA_MD5_SASL */
#include <sasl/md5.h>
/* Use the supplied definitions of MD5_CTX and te Init, Update, and Final functions */
#define NDML_MD5Init _sasl_MD5Init
#define NDML_MD5Update _sasl_MD5Update
#define NDML_MD5Final _sasl_MD5Final
#elif AMANDA_MD5_PKG_ENUM == 3	/* AMANDA_MD5_OPENSSL */
#include <openssl/md5.h>
/* Use the supplied definitions of MD5_CTX and te Init, Update, and Final functions */
#define NDML_MD5Init MD5_Init
#define NDML_MD5Update MD5_Update
#define NDML_MD5Final MD5_Final
#elif AMANDA_MD5_PKG_ENUM == 0	/* AMANDA_MD5_DEFAULT */
/* Use the host/system supplied definitions of MD5_CTX and te Init, Update, and Final functions */
#define NDML_MD5Init MD5Init
#define NDML_MD5Update MD5Update
#define NDML_MD5Final MD5Final
#elif AMANDA_MD5_PKG_ENUM == 2	/* AMANDA_MD5_AMANDA */

/* Use built in MD5 context */
typedef struct {
  UINT4 state[4];                                   /* state (ABCD) */
  UINT4 count[2];        /* number of bits, modulo 2^64 (lsb first) */
  unsigned char buffer[64];                         /* input buffer */
  unsigned int num;
} MD5_CTX;

void NDML_MD5Init PROTO_LIST ((MD5_CTX *));
void NDML_MD5Update PROTO_LIST
  ((MD5_CTX *, unsigned char *, unsigned int));
void NDML_MD5Final PROTO_LIST ((unsigned char [16], MD5_CTX *));

#else
#error "No recognized MD5 provider"
#endif
