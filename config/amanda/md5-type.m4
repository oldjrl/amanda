# SYNOPSIS
#
#   AMANDA_MD5_TYPE
#
# OVERVIEW
#
#   Handle configuration for MD5 digest, implementing the --with-md5-pkg
#   option and checking for the relevant programs and options.  Defines and substitutes
#

AC_DEFUN([AMANDA_MD5_TYPE],
[
    AC_DEFINE([AMANDA_MD5_DEFAULT], [0], [Use default (std) MD5 implementation])
    AC_DEFINE([AMANDA_MD5_PACKAGE], [1], [Use unknown pkg MD5 implementation])
    AC_DEFINE([AMANDA_MD5_AMANDA], [2], [Use internal MD5 implementation])
    AC_DEFINE([AMANDA_MD5_OPENSSL], [3], [Use openssl MD5 implementation])
    AC_DEFINE([AMANDA_MD5_SASL], [4], [Use SASL MD5 implementation])

    AC_ARG_WITH([md5-pkg],
        [AS_HELP_STRING([--with-md5-pkg],
	        [specify MD5 package])],
        [
	    AC_MSG_CHECKING([MD5 digest implementation])
	    case "$withval" in
		default)
		    AMANDA_MD5_PKG=$withval
		    AMANDA_MD5_CPPFLAGS="-DAMANDA_MD5_PKG_ENUM=0"
		    AMANDA_MD5_LIBADD=
		    ;;
	    	amanda) 
		    AMANDA_MD5_PKG=$withval
		    AMANDA_MD5_CPPFLAGS="-DAMANDA_MD5_PKG_ENUM=2"
		    AMANDA_MD5_LIBADD=
		    ;;
		openssl|libsasl2|*)
		    AS_IF([$PKG_CONFIG --exists $withval],
		          [
			     AMANDA_MD5_PKG=$withval
			     pkg_md5_cppflags=`$PKG_CONFIG --cflags $AMANDA_MD5_PKG 2>/dev/null`
			     pkg_md5_libadd=`$PKG_CONFIG --libs $AMANDA_MD5_PKG 2>/dev/null`
			     AMANDA_MD5_LIBADD="$pkg_md5_libadd"
			     case "$AMANDA_MD5_PKG" in
			     	 openssl)
				    AMANDA_MD5_CPPFLAGS="-DAMANDA_MD5_PKG_ENUM=3 $pkg_md5_cppflags"
				    ;;
				 libsasl2)
				    AMANDA_MD5_CPPFLAGS="-DAMANDA_MD5_PKG_ENUM=4 $pkg_md5_cppflags"
				    ;;
				 *)
				    AMANDA_MD5_CPPFLAGS="-DAMANDA_MD5_PKG_ENUM=1 $pkg_md5_cppflags"
				    ;;
			     esac
			],
	     		[AC_MSG_FAILURE([$PKG_CONFIG doesn't know about "$withval"])]
	      	    )
		    ;;
	    esac
	    AC_MSG_RESULT([$AMANDA_MD5_PKG ($AMANDA_MD5_CPPFLAGS $AMANDA_MD5_LIBADD)])
	],
	[AC_MSG_FAILURE([--with-md5-pkg must be specified (use --with-md5-pkg=amanda if an internal implementation is desired])]
    )
    AC_SUBST([AMANDA_MD5_PKG])
    AC_SUBST([AMANDA_MD5_CPPFLAGS])
    AC_SUBST([AMANDA_MD5_LIBADD])
    AM_CONDITIONAL([AMANDA_MD5_SOURCE], [test x$AMANDA_MD5_PKG = xamanda])
])
