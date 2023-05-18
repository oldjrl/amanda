# SYNOPSIS
#
#   AMANDA_WITH_PRESERVE_LOCALE
#
# OVERVIEW
#
#   define PRESERVE_LOCALE if we want locale information preserved across execs.
#
AC_DEFUN([AMANDA_WITH_PRESERVE_LOCALE],
[
    PRESERVE_LOCALE=${PRESERVE_LOCALE:-no}

    AC_ARG_WITH(preserve-locale,
        AS_HELP_STRING([--with-preserve-locale]
            [Preserve locale info across execs (safe_env)]),
        [   PRESERVE_LOCALE=$withval ])

    if test x"$PRESERVE_LOCALE" = x"yes"; then
        AC_DEFINE(PRESERVE_LOCALE, 1,
	    [Define if we should preserve locale info across execs (safe_env).])
	PRESERVE_LOCALE=1
    else
	PRESERVE_LOCALE=0
    fi
    AC_SUBST(PRESERVE_LOCALE)
])
