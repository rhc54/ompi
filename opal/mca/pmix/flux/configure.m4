# -*- shell-script -*-
#
# Copyright (c) 2014-2016 Intel, Inc.  All rights reserved.
# $COPYRIGHT$
#
# Additional copyrights may follow
#
# $HEADER$
#

# MCA_pmix_flux_CONFIG([action-if-found], [action-if-not-found])
# -----------------------------------------------------------
AC_DEFUN([MCA_opal_pmix_flux_CONFIG], [
    AC_CONFIG_FILES([opal/mca/pmix/flux/Makefile])

    AC_ARG_WITH([flux-pmi],
                [AC_HELP_STRING([--with-flux-pmi(=DIR)],
                                [Build Flux PMI support, optionally adding DIR to the search path (default: no)])],
                                [], with_flux_pmi=no)

    AC_ARG_WITH([flux-pmi-libdir],
                [AC_HELP_STRING([--with-flux-pmi-libdir(=DIR)],
                                [Look for libpmi in the given directory, DIR/lib or DIR/lib64])])

    flux_pmi_install_dir=
    flux_pmi_lib_dir=
    default_flux_pmi_loc=
    default_flux_pmi_libloc=

    # save flags
    flux_save_CPPFLAGS=$CPPFLAGS
    flux_save_LDFLAGS=$LDFLAGS
    flux_save_LIBS=$LIBS
    flux_hdr_happy=

    AC_MSG_CHECKING([if user requested Flux PMI support])
    AS_IF([test "$with_flux_pmi" = "no"],
          [AC_MSG_RESULT([no])
           $3],
          [AC_MSG_RESULT([yes])
           # cannot use OPAL_CHECK_PACKAGE as its backend header
           # support appends "include" to the path, which may not
           # work with flux if it follows slurm's practice :-(
           AS_IF([test ! -z "$with_flux_pmi" && test "$with_flux_pmi" != "yes"],
                 [flux_pmi_install_dir=$with_flux_pmi
                  default_flux_pmi_loc=no],
                 [flux_pmi_install_dir=/usr
                  default_flux_pmi_loc=yes])
           AS_IF([test ! -z "$with_flux_pmi_libdir"],
                 [flux_pmi_lib_dir=$with_flux_pmi_libdir
                  default_flux_pmi_libloc=no],
                 [flux_pmi_lib_dir=$flux_pmi_install_dir
          AS_IF([test "$default_flux_pmi_loc" = "no"],
                [default_flux_pmi_libloc=no],
                [default_flux_pmi_libloc=yes])])

           # check for the header - first in exact path */
           AC_MSG_CHECKING([for pmi.h in $flux_pmi_install_dir])
           AS_IF([test -f $flux_pmi_install_dir/pmi.h],
                 [AC_MSG_RESULT([found])
                  flux_hdr_happy=yes
                  flux_CPPFLAGS="-I$flux_pmi_install_dir"],
                 [AC_MSG_RESULT([not found])
                  AC_MSG_CHECKING([for pmi.h in $flux_pmi_install_dir/include])
                  AS_IF([test -f $flux_pmi_install_dir/include/pmi.h],
                        [AC_MSG_RESULT([found])
                         flux_hdr_happy=yes
                         flux_CPPFLAGS="-I$flux_pmi_install_dir/include"],
                        [AC_MSG_RESULT([not found])
                         flux_hdr_happy=no])])

           # check for library and function
           flux_lib_happy=
           LIBS="$LIBS -lpmi"

           # check for the library in the given location in case
           # an exact path was given
           AC_MSG_CHECKING([for libpmi in $flux_pmi_lib_dir])
           files=`ls $flux_pmi_lib_dir/libpmi.* 2> /dev/null | wc -l`
           AS_IF([test "$files" -gt "0"],
                 [AC_MSG_RESULT([found])
                  LDFLAGS="$LDFLAGS -L$flux_pmi_lib_dir"
                  AC_CHECK_LIB([pmi], [PMI_Init],
                               [flux_lib_happy=yes
                                flux_LDFLAGS=-L$flux_pmi_lib_dir
                                flux_rpath=$flux_pmi_lib_dir],
                               [flux_lib_happy=no])],
                 [flux_lib_happy=no
                  AC_MSG_RESULT([not found])])

           # check for presence of lib64 directory - if found, see if the
           # desired library is present and matches our build requirements
           files=`ls $flux_pmi_lib_dir/lib64/libpmi.* 2> /dev/null | wc -l`
           AS_IF([test "$flux_lib_happy" != "yes"],
                 [AC_MSG_CHECKING([for libpmi in $flux_pmi_lib_dir/lib64])
                  AS_IF([test "$files" -gt "0"],
                        [AC_MSG_RESULT([found])
                         LDFLAGS="$LDFLAGS -L$flux_pmi_lib_dir/lib64"
                         AC_CHECK_LIB([pmi], [PMI_Init],
                                      [flux_lib_happy=yes
                                       flux_LDFLAGS=-L$flux_pmi_lib_dir/lib64
                                       flux_rpath=$flux_pmi_lib_dir/lib64],
                                      [flux_lib_happy=no])],
                        [flux_lib_happy=no
                         AC_MSG_RESULT([not found])])])

           # if we didn't find lib64, or the library wasn't present or correct,
           # then try a lib directory if present
           files=`ls $flux_pmi_lib_dir/lib/libpmi.* 2> /dev/null | wc -l`
           AS_IF([test "$flux_lib_happy" != "yes"],
                 [AC_MSG_CHECKING([for libpmi in $flux_pmi_lib_dir/lib])
                  AS_IF([test "$files" -gt "0"],
                        [AC_MSG_RESULT([found])
                         LDFLAGS="$LDFLAGS -L$flux_pmi_lib_dir/lib"
                         AC_CHECK_LIB([pmi], [PMI_Init],
                                      [flux_lib_happy=yes
                                       flux_LDFLAGS=-L$flux_pmi_lib_dir/lib
                                       flux_rpath=$flux_pmi_lib_dir/lib],
                                      [flux_lib_happy=no])],
                        [flux_lib_happy=no
                         AC_MSG_RESULT([not found])])])

           AS_IF([test "$flux_hdr_happy" = "yes" && test "$flux_lib_happy" = "yes"],
                 [opal_enable_flux=yes
                  AS_IF([test "$default_flux_pmi_loc" = "no"],
                        [AC_SUBST(flux_CPPFLAGS)])
                  AS_IF([test "$default_flux_pmi_libloc" = "no"],
                        [AC_SUBST(flux_LDFLAGS)
                         AC_SUBST(flux_rpath)])],
                 [opal_enable_flux=no])

           # if support was explicitly requested, then we should error out
           # if we didn't find the required support
           AC_MSG_CHECKING([can Flux PMI support be built])
           AS_IF([test "$opal_enable_flux" != "yes"],
                 [AC_MSG_RESULT([no])
                  AC_MSG_WARN([Flux PMI support requested (via --with-flux-pmi) but pmi.h])
                  AC_MSG_WARN([was not found in location:])
                  AC_MSG_WARN([    $flux_pmi_install_dir/include])
                  AC_MSG_WARN([Specified path: $with_flux_pmi])
                  AC_MSG_WARN([OR libpmi was not found under:])
                  AC_MSG_WARN([    $flux_pmi_lib_dir])
                  AC_MSG_WARN([    $flux_pmi_lib_dir/lib])
                  AC_MSG_WARN([    $flux_pmi_lib_dir/lib64])
                  AC_MSG_WARN([Specified path: $with_flux_pmi_libdir])
                  AC_MSG_ERROR([Aborting])],
                 [AC_MSG_RESULT([yes])])
           ])

    # restore flags
    CPPFLAGS=$flux_save_CPPFLAGS
    LDFLAGS=$flux_save_LDFLAGS
    LIBS=$flux_save_LIBS


    # Evaluate succeed / fail
    AS_IF([test "$opal_enable_flux" = "yes"],
          [$1
           # need to set the wrapper flags for static builds
           pmix_flux_WRAPPER_EXTRA_LDFLAGS="$flux_LDFLAGS"
           pmix_flux_WRAPPER_EXTRA_LIBS="$flux_LIBS"],
          [$2])

])
